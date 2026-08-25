import 'dart:convert';
import 'dart:developer' as dev;
import 'package:crypto/crypto.dart';
import 'double_ratchet_session.dart';
import 'key_bundle.dart';
import 'secure_key_store.dart';
import 'signal_crypto_service.dart';

/// Manages X3DH key agreement and persistent Double Ratchet sessions
class SessionManager {
  final SecureKeyStore _secureKeyStore;
  final SignalCryptoService _cryptoService;

  // In-memory cache of active Double Ratchet sessions indexed by Peer User ID
  final Map<String, DoubleRatchetState> _sessions = {};

  SessionManager({
    SecureKeyStore? secureKeyStore,
    SignalCryptoService? cryptoService,
  })  : _secureKeyStore = secureKeyStore ?? SecureKeyStore(),
        _cryptoService = cryptoService ?? SignalCryptoService();

  /// 🔒 Encrypts an outgoing message using Double Ratchet
  Future<EncryptedPayload> encryptMessage({
    required String recipientId,
    required String serverUrl,
    required String plainText,
  }) async {
    DoubleRatchetState? session = _sessions[recipientId];
    String? x3dhEphemeralKey;
    int? usedOtPKId;

    // If no active session exists with recipient, initiate X3DH handshake
    if (session == null) {
      dev.log('[X3DH] No session with $recipientId. Fetching PreKey bundle from $serverUrl...',
          name: 'SessionManager');

      final bundle = await _cryptoService.fetchPreKeyBundle(
        serverUrl: serverUrl,
        targetUserId: recipientId,
      );

      if (bundle == null) {
        dev.log('⚠️ [X3DH] Could not fetch bundle for $recipientId. Falling back to local encryption.',
            name: 'SessionManager');
        // Fallback symmetric encryption if server is unreachable
        final localKey = DoubleRatchetEngine.generateRandomKey();
        return EncryptedPayload(
          isEncrypted: true,
          cipherText: _cryptoService.encryptMessage(plainText, localKey),
          ratchetPublicKey: '',
          sequenceNumber: 0,
        );
      }

      // Perform X3DH from Alice's side
      final myIdentityKey = await _secureKeyStore.getIdentityKeyPair();
      if (myIdentityKey == null) {
        throw Exception('Local Identity Key not found. App must generate keys first.');
      }

      // Generate Alice Ephemeral Key Pair
      final aliceEphemeralKey = DoubleRatchetEngine.generateKeyPair();
      x3dhEphemeralKey = aliceEphemeralKey.publicKey;

      // DH1 = DH(IK_A, SPK_B)
      final dh1 = DoubleRatchetEngine.computeDH(myIdentityKey.privateKey, bundle.signedPreKey.publicKey);
      // DH2 = DH(EK_A, IK_B)
      final dh2 = DoubleRatchetEngine.computeDH(aliceEphemeralKey.privateKey, bundle.identityKey);
      // DH3 = DH(EK_A, SPK_B)
      final dh3 = DoubleRatchetEngine.computeDH(aliceEphemeralKey.privateKey, bundle.signedPreKey.publicKey);

      // DH4 = DH(EK_A, OPK_B) if OTPK was returned by server
      String dh4 = '';
      if (bundle.oneTimePreKeys.isNotEmpty) {
        final otpk = bundle.oneTimePreKeys.first;
        usedOtPKId = otpk.keyId;
        dh4 = DoubleRatchetEngine.computeDH(aliceEphemeralKey.privateKey, otpk.publicKey);
      }

      // Compute Master Shared Secret (SK) = KDF(DH1 || DH2 || DH3 || DH4)
      final masterSK = _deriveMasterSecret([dh1, dh2, dh3, if (dh4.isNotEmpty) dh4]);

      // Initialize Double Ratchet session for Alice
      session = DoubleRatchetEngine.initAlice(
        peerId: recipientId,
        masterSharedSecret: masterSK,
        bobRatchetPublicKey: bundle.signedPreKey.publicKey,
      );
      _sessions[recipientId] = session;
      dev.log('✅ [X3DH] Double Ratchet session established with $recipientId (Alice Initiator)',
          name: 'SessionManager');
    }

    // Encrypt message with current ratchet state
    final payload = DoubleRatchetEngine.ratchetEncrypt(session, plainText);

    // If this is the initial X3DH message, attach ephemeral key & OTPK ID
    if (x3dhEphemeralKey != null) {
      return EncryptedPayload(
        isEncrypted: true,
        cipherText: payload.cipherText,
        ratchetPublicKey: payload.ratchetPublicKey,
        sequenceNumber: payload.sequenceNumber,
        previousChainLength: payload.previousChainLength,
        ephemeralKey: x3dhEphemeralKey,
        oneTimePreKeyId: usedOtPKId,
      );
    }

    return payload;
  }

  /// 🔓 Decrypts an incoming message payload using Double Ratchet
  Future<String> decryptMessage({
    required String senderId,
    required EncryptedPayload payload,
  }) async {
    DoubleRatchetState? session = _sessions[senderId];

    // If recipient (Bob) does not have an active session, initialize X3DH from Bob's side
    if (session == null) {
      if (payload.ephemeralKey == null) {
        // Fallback for non-session messages
        return _cryptoService.decryptMessage(payload.cipherText, payload.ratchetPublicKey);
      }

      dev.log('[X3DH] Processing initial session message from $senderId (Bob Recipient)...',
          name: 'SessionManager');

      final myIdentityKey = await _secureKeyStore.getIdentityKeyPair();
      final mySignedPreKey = await _secureKeyStore.getSignedPreKey();

      if (myIdentityKey == null || mySignedPreKey == null) {
        throw Exception('Local keys missing for decrypting session message.');
      }

      // Reconstruct DH components from Bob's perspective
      // DH1 = DH(SPK_B, IK_A)
      final dh1 = DoubleRatchetEngine.computeDH(mySignedPreKey.privateKey!, payload.ratchetPublicKey);
      // DH2 = DH(IK_B, EK_A)
      final dh2 = DoubleRatchetEngine.computeDH(myIdentityKey.privateKey, payload.ephemeralKey!);
      // DH3 = DH(SPK_B, EK_A)
      final dh3 = DoubleRatchetEngine.computeDH(mySignedPreKey.privateKey!, payload.ephemeralKey!);

      // DH4 = DH(OPK_B, EK_A) if used
      String dh4 = '';
      if (payload.oneTimePreKeyId != null) {
        final otpk = await _secureKeyStore.getOneTimePreKey(payload.oneTimePreKeyId!);
        if (otpk != null && otpk.privateKey != null) {
          dh4 = DoubleRatchetEngine.computeDH(otpk.privateKey!, payload.ephemeralKey!);
        }
      }

      final masterSK = _deriveMasterSecret([dh1, dh2, dh3, if (dh4.isNotEmpty) dh4]);

      session = DoubleRatchetEngine.initBob(
        peerId: senderId,
        masterSharedSecret: masterSK,
        bobRatchetKeyPair: IdentityKeyPair(
          publicKey: mySignedPreKey.publicKey,
          privateKey: mySignedPreKey.privateKey!,
        ),
      );
      _sessions[senderId] = session;
      dev.log('✅ [X3DH] Double Ratchet session initialized for $senderId (Bob Recipient)',
          name: 'SessionManager');
    }

    // Pass through Double Ratchet decryption
    return DoubleRatchetEngine.ratchetDecrypt(session, payload);
  }

  /// Derives 32-byte master key from concatenated DH secrets via SHA-256
  String _deriveMasterSecret(List<String> dhSecrets) {
    final concatenated = dhSecrets.join('::');
    final digest = sha256.convert(utf8.encode(concatenated));
    return base64Encode(digest.bytes);
  }

  /// Resets session with peer (e.g. for re-keying)
  void clearSession(String peerId) {
    _sessions.remove(peerId);
  }
}

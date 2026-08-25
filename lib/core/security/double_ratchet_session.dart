import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'key_bundle.dart';

/// Serializable Double Ratchet session state
class DoubleRatchetState {
  String peerId;
  String rootKey; // RK (Base64)
  String? sendingChainKey; // CKs (Base64)
  String? receivingChainKey; // CKr (Base64)
  IdentityKeyPair sendingRatchetKeyPair; // DHs (Private + Public)
  String? receivingRatchetPublicKey; // DHr (Public)
  int sequenceNumberSending; // Ns
  int sequenceNumberReceiving; // Nr
  int previousSendingChainLength; // PNs

  // Stores skipped message keys for out-of-order messages: Map of "RatchetPub:SeqNum" -> MK
  Map<String, String> skippedMessageKeys;

  DoubleRatchetState({
    required this.peerId,
    required this.rootKey,
    this.sendingChainKey,
    this.receivingChainKey,
    required this.sendingRatchetKeyPair,
    this.receivingRatchetPublicKey,
    this.sequenceNumberSending = 0,
    this.sequenceNumberReceiving = 0,
    this.previousSendingChainLength = 0,
    Map<String, String>? skippedMessageKeys,
  }) : skippedMessageKeys = skippedMessageKeys ?? {};

  Map<String, dynamic> toJson() => {
        'peerId': peerId,
        'rootKey': rootKey,
        'sendingChainKey': sendingChainKey,
        'receivingChainKey': receivingChainKey,
        'sendingRatchetKeyPair': sendingRatchetKeyPair.toJson(),
        'receivingRatchetPublicKey': receivingRatchetPublicKey,
        'sequenceNumberSending': sequenceNumberSending,
        'sequenceNumberReceiving': sequenceNumberReceiving,
        'previousSendingChainLength': previousSendingChainLength,
        'skippedMessageKeys': skippedMessageKeys,
      };

  factory DoubleRatchetState.fromJson(Map<String, dynamic> json) => DoubleRatchetState(
        peerId: json['peerId'] as String,
        rootKey: json['rootKey'] as String,
        sendingChainKey: json['sendingChainKey'] as String?,
        receivingChainKey: json['receivingChainKey'] as String?,
        sendingRatchetKeyPair: IdentityKeyPair.fromJson(
            json['sendingRatchetKeyPair'] as Map<String, dynamic>),
        receivingRatchetPublicKey: json['receivingRatchetPublicKey'] as String?,
        sequenceNumberSending: json['sequenceNumberSending'] as int? ?? 0,
        sequenceNumberReceiving: json['sequenceNumberReceiving'] as int? ?? 0,
        previousSendingChainLength: json['previousSendingChainLength'] as int? ?? 0,
        skippedMessageKeys:
            (json['skippedMessageKeys'] as Map<String, dynamic>?)?.map(
                  (k, v) => MapEntry(k, v as String),
                ) ??
                {},
      );
}

/// Core Double Ratchet cryptographic engine
class DoubleRatchetEngine {
  static String generateRandomKey() {
    final random = Random.secure();
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Encode(bytes);
  }

  static IdentityKeyPair generateKeyPair() {
    final priv = generateRandomKey();
    final pubDigest = sha256.convert(base64Decode(priv));
    final pub = base64Encode(pubDigest.bytes);
    return IdentityKeyPair(publicKey: pub, privateKey: priv);
  }

  /// Diffie-Hellman scalar agreement (Curve25519 simulation via SHA-256)
  static String computeDH(String privateKeyBase64, String publicKeyBase64) {
    final privBytes = base64Decode(privateKeyBase64);
    final pubBytes = base64Decode(publicKeyBase64);
    final combined = Uint8List(privBytes.length + pubBytes.length)
      ..setAll(0, privBytes)
      ..setAll(privBytes.length, pubBytes);
    return base64Encode(sha256.convert(combined).bytes);
  }

  /// Root KDF (Derives new Root Key and Chain Key from DH output)
  static (String nextRootKey, String chainKey) kdfRK(String rootKeyBase64, String dhOutputBase64) {
    final rkBytes = base64Decode(rootKeyBase64);
    final dhBytes = base64Decode(dhOutputBase64);

    final hmac = Hmac(sha256, rkBytes);
    final derived = hmac.convert(dhBytes).bytes;

    final nextRk = base64Encode(sha256.convert(Uint8List.fromList(derived + [0x01])).bytes);
    final chainKey = base64Encode(sha256.convert(Uint8List.fromList(derived + [0x02])).bytes);
    return (nextRk, chainKey);
  }

  /// Chain KDF (Derives new Chain Key and ephemeral Message Key)
  static (String nextChainKey, String messageKey) kdfCK(String chainKeyBase64) {
    final ckBytes = base64Decode(chainKeyBase64);
    final hmac = Hmac(sha256, ckBytes);

    final nextCk = base64Encode(hmac.convert([0x01]).bytes);
    final messageKey = base64Encode(hmac.convert([0x02]).bytes);
    return (nextCk, messageKey);
  }

  /// Initializes a Double Ratchet session for Alice (the session initiator)
  static DoubleRatchetState initAlice({
    required String peerId,
    required String masterSharedSecret, // SK derived via X3DH
    required String bobRatchetPublicKey,
  }) {
    final aliceRatchetKeyPair = generateKeyPair();
    final dhOut = computeDH(aliceRatchetKeyPair.privateKey, bobRatchetPublicKey);
    final (nextRk, sendingCk) = kdfRK(masterSharedSecret, dhOut);

    return DoubleRatchetState(
      peerId: peerId,
      rootKey: nextRk,
      sendingChainKey: sendingCk,
      receivingChainKey: null,
      sendingRatchetKeyPair: aliceRatchetKeyPair,
      receivingRatchetPublicKey: bobRatchetPublicKey,
    );
  }

  /// Initializes a Double Ratchet session for Bob (the session recipient)
  static DoubleRatchetState initBob({
    required String peerId,
    required String masterSharedSecret, // SK derived via X3DH
    required IdentityKeyPair bobRatchetKeyPair,
  }) {
    return DoubleRatchetState(
      peerId: peerId,
      rootKey: masterSharedSecret,
      sendingChainKey: null,
      receivingChainKey: null,
      sendingRatchetKeyPair: bobRatchetKeyPair,
      receivingRatchetPublicKey: null,
    );
  }

  /// 🔒 Encrypts plainText and advances sending symmetric ratchet
  static EncryptedPayload ratchetEncrypt(DoubleRatchetState state, String plainText) {
    if (state.sendingChainKey == null) {
      final (nextRk, sendingCk) = kdfRK(state.rootKey, state.sendingRatchetKeyPair.privateKey);
      state.rootKey = nextRk;
      state.sendingChainKey = sendingCk;
    }

    // Advance symmetric sending ratchet chain
    final (nextCk, messageKey) = kdfCK(state.sendingChainKey!);
    state.sendingChainKey = nextCk;

    // Encrypt payload with derived message key
    final cipherText = _symmetricEncrypt(plainText, messageKey);
    final seqNum = state.sequenceNumberSending;
    state.sequenceNumberSending++;

    return EncryptedPayload(
      isEncrypted: true,
      cipherText: cipherText,
      ratchetPublicKey: state.sendingRatchetKeyPair.publicKey,
      sequenceNumber: seqNum,
      previousChainLength: state.previousSendingChainLength,
    );
  }

  /// 🔓 Decrypts EncryptedPayload and advances DH & symmetric ratchets
  static String ratchetDecrypt(DoubleRatchetState state, EncryptedPayload payload) {
    // 1. Check if recipient needs a DH Ratchet step (remote ratchet key changed)
    if (payload.ratchetPublicKey.isNotEmpty &&
        payload.ratchetPublicKey != state.receivingRatchetPublicKey) {
      _dhRatchetStep(state, payload.ratchetPublicKey);
    }

    if (state.receivingChainKey == null) {
      throw Exception('Double Ratchet receiving chain key is null');
    }

    // 2. Advance symmetric receiving ratchet chain
    final (nextCk, messageKey) = kdfCK(state.receivingChainKey!);
    state.receivingChainKey = nextCk;
    state.sequenceNumberReceiving++;

    // 3. Decrypt ciphertext
    return _symmetricDecrypt(payload.cipherText, messageKey);
  }

  /// Performs a DH Ratchet step when a new peer ratchet public key is observed
  static void _dhRatchetStep(DoubleRatchetState state, String remoteRatchetPublicKey) {
    state.previousSendingChainLength = state.sequenceNumberSending;
    state.sequenceNumberSending = 0;
    state.sequenceNumberReceiving = 0;
    state.receivingRatchetPublicKey = remoteRatchetPublicKey;

    // 1. Derive receiving chain key using existing DHs and new DHr
    final dhReceive = computeDH(state.sendingRatchetKeyPair.privateKey, remoteRatchetPublicKey);
    final (rk1, receivingCk) = kdfRK(state.rootKey, dhReceive);
    state.rootKey = rk1;
    state.receivingChainKey = receivingCk;

    // 2. Generate new DHs and derive new sending chain key
    state.sendingRatchetKeyPair = generateKeyPair();
    final dhSend = computeDH(state.sendingRatchetKeyPair.privateKey, remoteRatchetPublicKey);
    final (rk2, sendingCk) = kdfRK(state.rootKey, dhSend);
    state.rootKey = rk2;
    state.sendingChainKey = sendingCk;
  }

  static String _symmetricEncrypt(String plainText, String messageKeyBase64) {
    final keyBytes = sha256.convert(base64Decode(messageKeyBase64)).bytes;
    final textBytes = utf8.encode(plainText);
    final encrypted = Uint8List(textBytes.length);

    for (int i = 0; i < textBytes.length; i++) {
      encrypted[i] = textBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return base64Encode(encrypted);
  }

  static String _symmetricDecrypt(String cipherTextBase64, String messageKeyBase64) {
    final keyBytes = sha256.convert(base64Decode(messageKeyBase64)).bytes;
    final cipherBytes = base64Decode(cipherTextBase64);
    final decrypted = Uint8List(cipherBytes.length);

    for (int i = 0; i < cipherBytes.length; i++) {
      decrypted[i] = cipherBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return utf8.decode(decrypted);
  }
}

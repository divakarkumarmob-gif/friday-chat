import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'key_bundle.dart';
import 'secure_key_store.dart';

class SignalCryptoService {
  final SecureKeyStore _secureKeyStore;

  SignalCryptoService({SecureKeyStore? secureKeyStore})
      : _secureKeyStore = secureKeyStore ?? SecureKeyStore();

  /// Generates a cryptographically strong 32-byte random key encoded in Base64
  String _generateRandomBytes(int length) {
    final random = Random.secure();
    final values = Uint8List(length);
    for (int i = 0; i < length; i++) {
      values[i] = random.nextInt(256);
    }
    return base64Encode(values);
  }

  /// Derives public key from private key (Curve25519 / SHA-256 scalar point simulation)
  String _derivePublicKey(String privateKeyBase64) {
    final privateBytes = base64Decode(privateKeyBase64);
    final digest = sha256.convert(privateBytes);
    return base64Encode(digest.bytes);
  }

  /// Signs data with identity private key using HMAC-SHA256
  String _signData(String data, String privateKeyBase64) {
    final hmac = Hmac(sha256, base64Decode(privateKeyBase64));
    final signature = hmac.convert(utf8.encode(data));
    return base64Encode(signature.bytes);
  }

  /// 🔑 1. Generates Identity Key Pair, Registration ID, Signed PreKey, and One-Time PreKeys,
  /// saves private keys to secure storage, and uploads public keys to Go backend.
  Future<PreKeyBundle> generateAndRegisterKeys({
    required String userId,
    required String serverUrl,
  }) async {
    dev.log('[E2EE] Initializing Signal Protocol Key Generation for $userId...', name: 'SignalCryptoService');

    // 1. Check for existing Identity Key or create new
    IdentityKeyPair? identityKey = await _secureKeyStore.getIdentityKeyPair();
    int? registrationId = await _secureKeyStore.getRegistrationId();

    if (identityKey == null || registrationId == null) {
      final identityPriv = _generateRandomBytes(32);
      final identityPub = _derivePublicKey(identityPriv);
      identityKey = IdentityKeyPair(publicKey: identityPub, privateKey: identityPriv);
      registrationId = 10000 + Random.secure().nextInt(9999000);

      await _secureKeyStore.saveIdentityKeyPair(identityKey);
      await _secureKeyStore.saveRegistrationId(registrationId);
      dev.log('[E2EE] Generated new Identity Key & Registration ID: $registrationId', name: 'SignalCryptoService');
    }

    // 2. Generate Signed PreKey (Key ID = 1)
    final signedPriv = _generateRandomBytes(32);
    final signedPub = _derivePublicKey(signedPriv);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final signature = _signData(signedPub, identityKey.privateKey);

    final signedPreKey = SignedPreKey(
      keyId: 1,
      publicKey: signedPub,
      privateKey: signedPriv,
      signature: signature,
      timestamp: timestamp,
    );
    await _secureKeyStore.saveSignedPreKey(signedPreKey);

    // 3. Generate batch of 100 One-Time PreKeys (Key IDs 1..100)
    final List<OneTimePreKey> oneTimePreKeys = [];
    for (int i = 1; i <= 100; i++) {
      final otpkPriv = _generateRandomBytes(32);
      final otpkPub = _derivePublicKey(otpkPriv);
      oneTimePreKeys.add(
        OneTimePreKey(
          keyId: i,
          publicKey: otpkPub,
          privateKey: otpkPriv,
        ),
      );
    }
    await _secureKeyStore.saveOneTimePreKeys(oneTimePreKeys);
    dev.log('[E2EE] Generated 100 One-Time PreKeys and securely persisted private keys.', name: 'SignalCryptoService');

    // 4. Construct Public PreKey Bundle (excluding all private keys)
    final publicBundle = PreKeyBundle(
      userId: userId,
      registrationId: registrationId,
      identityKey: identityKey.publicKey,
      signedPreKey: SignedPreKey(
        keyId: signedPreKey.keyId,
        publicKey: signedPreKey.publicKey,
        signature: signedPreKey.signature,
        timestamp: signedPreKey.timestamp,
      ),
      oneTimePreKeys: oneTimePreKeys
          .map((pk) => OneTimePreKey(keyId: pk.keyId, publicKey: pk.publicKey))
          .toList(),
    );

    // 5. Upload Public PreKey Bundle to Go Backend Server
    await uploadPreKeyBundle(serverUrl: serverUrl, bundle: publicBundle);

    return publicBundle;
  }

  /// 🚀 2. Uploads the public PreKey bundle to the Go backend server
  Future<void> uploadPreKeyBundle({
    required String serverUrl,
    required PreKeyBundle bundle,
  }) async {
    final uri = Uri.parse('$serverUrl/api/v1/users/${bundle.userId}/key-bundle');
    dev.log('[E2EE] Uploading public PreKey bundle to $uri...', name: 'SignalCryptoService');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bundle.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        dev.log('✅ [E2EE] PreKey bundle successfully registered on server!', name: 'SignalCryptoService');
      } else {
        dev.log('⚠️ [E2EE] Failed to upload PreKey bundle: ${response.statusCode} - ${response.body}',
            name: 'SignalCryptoService');
      }
    } catch (e) {
      dev.log('⚠️ [E2EE] Network error uploading PreKey bundle (Server might be offline): $e',
          name: 'SignalCryptoService');
    }
  }

  /// 📥 3. Fetches a target peer's public PreKey bundle to initiate X3DH session
  Future<PreKeyBundle?> fetchPreKeyBundle({
    required String serverUrl,
    required String targetUserId,
  }) async {
    final uri = Uri.parse('$serverUrl/api/v1/users/$targetUserId/key-bundle');
    dev.log('[E2EE] Fetching PreKey bundle for $targetUserId from $uri...', name: 'SignalCryptoService');

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return PreKeyBundle.fromJson(data);
      }
    } catch (e) {
      dev.log('[E2EE] Error fetching PreKey bundle for $targetUserId: $e', name: 'SignalCryptoService');
    }
    return null;
  }

  /// 🔒 4. Encrypts a message using derived shared secret (AES-GCM / XOR stream cipher simulation)
  String encryptMessage(String plainText, String sharedSecret) {
    final keyBytes = sha256.convert(utf8.encode(sharedSecret)).bytes;
    final textBytes = utf8.encode(plainText);
    final encrypted = Uint8List(textBytes.length);

    for (int i = 0; i < textBytes.length; i++) {
      encrypted[i] = textBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return base64Encode(encrypted);
  }

  /// 🔓 5. Decrypts ciphertext using derived shared secret
  String decryptMessage(String cipherTextBase64, String sharedSecret) {
    final keyBytes = sha256.convert(utf8.encode(sharedSecret)).bytes;
    final cipherBytes = base64Decode(cipherTextBase64);
    final decrypted = Uint8List(cipherBytes.length);

    for (int i = 0; i < cipherBytes.length; i++) {
      decrypted[i] = cipherBytes[i] ^ keyBytes[i % keyBytes.length];
    }
    return utf8.decode(decrypted);
  }
}

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'key_bundle.dart';

/// Secure enclave storage for storing private cryptographic keys on the device
class SecureKeyStore {
  final FlutterSecureStorage _storage;

  SecureKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  static const String _keyRegistrationId = 'e2ee_registration_id';
  static const String _keyIdentityKeyPair = 'e2ee_identity_key_pair';
  static const String _keySignedPreKey = 'e2ee_signed_pre_key';
  static const String _keyOneTimePreKeysPrefix = 'e2ee_otpk_';

  // --- Registration ID ---
  Future<void> saveRegistrationId(int registrationId) async {
    await _storage.write(key: _keyRegistrationId, value: registrationId.toString());
  }

  Future<int?> getRegistrationId() async {
    final val = await _storage.read(key: _keyRegistrationId);
    return val != null ? int.tryParse(val) : null;
  }

  // --- Identity Key Pair (Private & Public) ---
  Future<void> saveIdentityKeyPair(IdentityKeyPair keyPair) async {
    await _storage.write(
      key: _keyIdentityKeyPair,
      value: jsonEncode(keyPair.toJson()),
    );
  }

  Future<IdentityKeyPair?> getIdentityKeyPair() async {
    final raw = await _storage.read(key: _keyIdentityKeyPair);
    if (raw == null) return null;
    return IdentityKeyPair.fromJson(jsonDecode(raw));
  }

  // --- Signed PreKey (with Private Key) ---
  Future<void> saveSignedPreKey(SignedPreKey signedPreKey) async {
    await _storage.write(
      key: _keySignedPreKey,
      value: jsonEncode(signedPreKey.toJson()),
    );
  }

  Future<SignedPreKey?> getSignedPreKey() async {
    final raw = await _storage.read(key: _keySignedPreKey);
    if (raw == null) return null;
    return SignedPreKey.fromJson(jsonDecode(raw));
  }

  // --- One-Time PreKeys ---
  Future<void> saveOneTimePreKeys(List<OneTimePreKey> preKeys) async {
    for (final pk in preKeys) {
      await _storage.write(
        key: '$_keyOneTimePreKeysPrefix${pk.keyId}',
        value: jsonEncode(pk.toJson()),
      );
    }
  }

  Future<OneTimePreKey?> getOneTimePreKey(int keyId) async {
    final raw = await _storage.read(key: '$_keyOneTimePreKeysPrefix$keyId');
    if (raw == null) return null;
    return OneTimePreKey.fromJson(jsonDecode(raw));
  }

  /// Clears all keys upon account logout / reset
  Future<void> clearAllKeys() async {
    await _storage.deleteAll();
  }
}

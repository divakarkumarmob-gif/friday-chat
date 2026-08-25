import 'dart:convert';

/// Represents the long-term Identity Key Pair of the user
class IdentityKeyPair {
  final String publicKey; // Base64 encoded Curve25519 public key
  final String privateKey; // Base64 encoded Curve25519 private key

  const IdentityKeyPair({
    required this.publicKey,
    required this.privateKey,
  });

  Map<String, dynamic> toJson() => {
        'publicKey': publicKey,
        'privateKey': privateKey,
      };

  factory IdentityKeyPair.fromJson(Map<String, dynamic> json) => IdentityKeyPair(
        publicKey: json['publicKey'] as String,
        privateKey: json['privateKey'] as String,
      );
}

/// Represents a Signed PreKey (rotated periodically, signed by Identity Key)
class SignedPreKey {
  final int keyId;
  final String publicKey;
  final String? privateKey; // Null when transmitted publicly
  final String signature;
  final int timestamp;

  const SignedPreKey({
    required this.keyId,
    required this.publicKey,
    this.privateKey,
    required this.signature,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'keyId': keyId,
        'publicKey': publicKey,
        if (privateKey != null) 'privateKey': privateKey,
        'signature': signature,
        'timestamp': timestamp,
      };

  factory SignedPreKey.fromJson(Map<String, dynamic> json) => SignedPreKey(
        keyId: json['keyId'] as int,
        publicKey: json['publicKey'] as String,
        privateKey: json['privateKey'] as String?,
        signature: json['signature'] as String,
        timestamp: json['timestamp'] as int,
      );
}

/// Represents a One-Time PreKey (consumed during X3DH key agreement)
class OneTimePreKey {
  final int keyId;
  final String publicKey;
  final String? privateKey; // Null when transmitted publicly

  const OneTimePreKey({
    required this.keyId,
    required this.publicKey,
    this.privateKey,
  });

  Map<String, dynamic> toJson() => {
        'keyId': keyId,
        'publicKey': publicKey,
        if (privateKey != null) 'privateKey': privateKey,
      };

  factory OneTimePreKey.fromJson(Map<String, dynamic> json) => OneTimePreKey(
        keyId: json['keyId'] as int,
        publicKey: json['publicKey'] as String,
        privateKey: json['privateKey'] as String?,
      );
}

/// Public PreKey Bundle uploaded to the server and retrieved by peers
class PreKeyBundle {
  final String userId;
  final int registrationId;
  final String identityKey;
  final SignedPreKey signedPreKey;
  final List<OneTimePreKey> oneTimePreKeys;

  const PreKeyBundle({
    required this.userId,
    required this.registrationId,
    required this.identityKey,
    required this.signedPreKey,
    required this.oneTimePreKeys,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'registrationId': registrationId,
        'identityKey': identityKey,
        'signedPreKey': signedPreKey.toJson(),
        'oneTimePreKeys': oneTimePreKeys.map((k) => k.toJson()).toList(),
      };

  factory PreKeyBundle.fromJson(Map<String, dynamic> json) => PreKeyBundle(
        userId: json['userId'] as String,
        registrationId: json['registrationId'] as int,
        identityKey: json['identityKey'] as String,
        signedPreKey: SignedPreKey.fromJson(json['signedPreKey'] as Map<String, dynamic>),
        oneTimePreKeys: (json['oneTimePreKeys'] as List<dynamic>?)
                ?.map((k) => OneTimePreKey.fromJson(k as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Encrypted message payload transmitted over the network (Double Ratchet Frame)
class EncryptedPayload {
  final bool isEncrypted;
  final String cipherText;
  final String ratchetPublicKey;
  final int sequenceNumber; // Ns
  final int previousChainLength; // PNs
  final String? ephemeralKey; // X3DH ephemeral public key for initial session message
  final int? oneTimePreKeyId;

  const EncryptedPayload({
    this.isEncrypted = true,
    required this.cipherText,
    required this.ratchetPublicKey,
    required this.sequenceNumber,
    this.previousChainLength = 0,
    this.ephemeralKey,
    this.oneTimePreKeyId,
  });

  Map<String, dynamic> toJson() => {
        'isEncrypted': isEncrypted,
        'cipherText': cipherText,
        'ratchetPublicKey': ratchetPublicKey,
        'sequenceNumber': sequenceNumber,
        'previousChainLength': previousChainLength,
        if (ephemeralKey != null) 'ephemeralKey': ephemeralKey,
        if (oneTimePreKeyId != null) 'oneTimePreKeyId': oneTimePreKeyId,
      };

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) => EncryptedPayload(
        isEncrypted: json['isEncrypted'] as bool? ?? true,
        cipherText: json['cipherText'] as String,
        ratchetPublicKey: json['ratchetPublicKey'] as String? ?? '',
        sequenceNumber: json['sequenceNumber'] as int? ?? 0,
        previousChainLength: json['previousChainLength'] as int? ?? 0,
        ephemeralKey: json['ephemeralKey'] as String?,
        oneTimePreKeyId: json['oneTimePreKeyId'] as int?,
      );
}

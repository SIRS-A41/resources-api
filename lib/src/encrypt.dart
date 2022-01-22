import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:encrypt/encrypt.dart';

final Random _random = Random.secure();
const int KEY_LENGTH = 256;

String generateKey() {
  var values = List<int>.generate(KEY_LENGTH ~/ 8, (i) => _random.nextInt(256));
  return base64.encode(values);
}

// ignore: always_declare_return_types
_parsePublicKey(String key) {
  // ignore: prefer_single_quotes
  return parseRSAPublicKeyPEM("""
  -----BEGIN PUBLIC KEY-----
  $key
  -----END PUBLIC KEY-----
  """);
}

String encryptPublic(String key, String plainText) {
  final publicKey = _parsePublicKey(key);
  final encrypter = Encrypter(RSA(publicKey: publicKey));

  final encrypted = encrypter.encrypt(plainText);

  return encrypted.base64;
}

List<int> _fileHash(List<int> fileBytes) {
  final digest = sha256.convert(fileBytes);
  return digest.bytes;
}

String? verifySignature(
    List<int> fileBytes, String signature, String publicKey) {
  final signer = Signer(
    RSASigner(
      RSASignDigest.SHA256,
      publicKey: _parsePublicKey(publicKey),
    ),
  );

  final _signature = Encrypted.fromBase64(signature);
  final hash = _fileHash(fileBytes);
  final valid = signer.verifyBytes(hash, _signature);
  if (valid) {
    final hex = hash.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    // return base64.encode(hash);
    return hex;
  } else {
    return null;
  }
}

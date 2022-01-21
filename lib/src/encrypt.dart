import 'dart:convert';
import 'dart:math';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:encrypt/encrypt.dart';

final Random _random = Random.secure();
const int KEY_LENGTH = 256;

String generateKey() {
  var values = List<int>.generate(KEY_LENGTH ~/ 8, (i) => _random.nextInt(256));
  return base64.encode(values);
}

String encryptPublic(String key, String plainText) {
  // ignore: prefer_single_quotes
  final publicKey = parseRSAPublicKeyPEM("""
  -----BEGIN PUBLIC KEY-----
  $key
  -----END PUBLIC KEY-----
  """);
  final encrypter = Encrypter(RSA(publicKey: publicKey));

  final encrypted = encrypter.encrypt(plainText);

  return encrypted.base64;
}

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// JWT HS256 per Stream Chat (user_id).
/// In produzione conviene generare il token su backend e non tenere la secret in app.
String createStreamUserToken({
  required String userId,
  required String apiSecret,
  Duration validity = const Duration(hours: 24),
}) {
  return _signJwt(
    apiSecret: apiSecret,
    claims: {
      'user_id': userId,
      'iat': _nowSeconds(),
      'exp': _nowSeconds() + validity.inSeconds,
    },
  );
}

/// JWT server-side Stream (`server: true`) per upsert utenti / operazioni admin.
String createStreamServerToken({
  required String apiSecret,
  Duration validity = const Duration(hours: 1),
}) {
  return _signJwt(
    apiSecret: apiSecret,
    claims: {
      'server': true,
      'iat': _nowSeconds(),
      'exp': _nowSeconds() + validity.inSeconds,
    },
  );
}

int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

String _signJwt({
  required String apiSecret,
  required Map<String, Object?> claims,
}) {
  final header = _base64UrlEncode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})));
  final payload = _base64UrlEncode(utf8.encode(jsonEncode(claims)));
  final data = '$header.$payload';
  final hmac = Hmac(sha256, utf8.encode(apiSecret));
  final signature = _base64UrlEncode(hmac.convert(utf8.encode(data)).bytes);
  return '$data.$signature';
}

String _base64UrlEncode(List<int> bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

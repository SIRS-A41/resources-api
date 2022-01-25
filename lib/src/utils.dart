import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../server.dart';

Middleware handleCors() {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE',
    'Access-Control-Allow-Headers': 'Origin,Content-Type,Authorization',
  };

  return createMiddleware(
    requestHandler: (Request request) {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }
      return null;
    },
    responseHandler: (Response response) {
      return response.change(headers: corsHeaders);
    },
  );
}

Middleware handleAuth(String localAuthIp, String basicAuthorization) {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['Authorization'];

      if (authHeader != null) {
        if (authHeader.startsWith('Bearer ')) {
          final token = authHeader.substring(7);

          final userId =
              await verifyJwt(token, localAuthIp, basicAuthorization);
          if (userId == null) {
            return Response.forbidden(
              'Not authorized to perform this action.',
            );
          }

          final updatedRequest = request.change(context: {
            'userId': userId,
          });
          return innerHandler(updatedRequest);
        } else {
          return Response.forbidden(
            'Not authorized to perform this action.',
          );
        }
      } else {
        return await innerHandler(request);
      }
    };
  };
}

Middleware checkAuthorization() {
  return createMiddleware(
    requestHandler: (Request request) {
      final userId = request.context['userId'];
      if (userId == null) {
        return Response.forbidden('Not authorized to perform this action.');
      }
      return null;
    },
  );
}

Middleware logUserRequests() {
  return createMiddleware(
    requestHandler: (Request req) {
      final userId = req.context['userId'];
      if (userId != null) {
        print(
            '${DateTime.now().toIso8601String()}\tuser: $userId\t${req.method}\t${req.requestedUri}');
      }
      return null;
    },
  );
}

Future<String?> verifyJwt(
    String token, String localAuthIp, String basicAuthorization) async {
  final response =
      await validationRequest(localAuthIp, token, basicAuthorization);

  if (response.statusCode == 200) {
    return await _readResponse(response);
  } else {
    return null;
  }
}

Future<HttpClientResponse> validationRequest(
    String localAuthIp, String token, String basicAuthorization) async {
  final context = getSecurityContext();
  final client = _createHttpClient(context);

  // The rest of this code comes from your question.
  final uri = Uri.https('$localAuthIp:8445', '/auth/validate');
  final data = jsonEncode(
    {'access_token': token},
  );

  var request = await client.openUrl('POST', uri);
  request.headers.set('Authorization', 'Basic $basicAuthorization');
  request.headers.set('Content-Type', 'application/json');
  request.write(data);
  final response = await request.close();
  return response;
}

HttpClient _createHttpClient(SecurityContext? context) {
  return HttpClient(context: context)
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      if (host.isNotEmpty && host == '192.168.1.112') {
        return true;
      } else {
        return false;
      }
    };
}

Future<String> _readResponse(HttpClientResponse response) {
  final completer = Completer<String>();
  final contents = StringBuffer();
  response.transform(utf8.decoder).listen((data) {
    contents.write(data);
  }, onDone: () => completer.complete(contents.toString()));
  return completer.future;
}

SecurityContext getSecurityContext() {
  // Bind with a secure HTTPS connection
  final chain =
      Platform.script.resolve('../certificates/cert.pem').toFilePath();
  final key = Platform.script.resolve('../certificates/key.pem').toFilePath();

  return SecurityContext()
    ..useCertificateChain(chain)
    ..usePrivateKey(key, password: 'changeit');
}

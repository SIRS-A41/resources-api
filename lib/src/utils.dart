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
  final url = Uri.http('$localAuthIp:8080', '/auth/validate');
  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Basic $basicAuthorization',
      'Content-Type': 'application/json',
    },
    body: jsonEncode(
      {'access_token': token},
    ),
  );

  if (response.statusCode == 200) {
    return response.body;
  } else {
    return null;
  }
}

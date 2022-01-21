import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:http/http.dart' as http;

import '../server.dart';

const String BASIC_AUTHORIZATION =
    'Basic QzZFNTlCMjlBRDZEODRCMEU0RUJGQjAzNkRFNzVFMUQ6VjJaMnBBdEZhYUQ3THRVaHRHYkJOQTUraUtDajFmdysybSttNlhVaDdUWT0=';
final AUTH_IP = Platform.environment['AUTH_IP'];
// final AUTH_API_HOSTNAME = '$AUTH_IP:8080';
final AUTH_API_HOSTNAME = '194.210.62.182:8080';

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

Middleware handleAuth() {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['Authorization'];

      if (authHeader != null) {
        if (authHeader.startsWith('Bearer ')) {
          final token = authHeader.substring(7);

          final userId = await verifyJwt(token);
          if (userId == null) {
            return Response.forbidden(
              'Not authorized to perform this action.',
            );
          }

          final updatedRequest = request.change(context: {
            'userId': userId,
          });
          return await innerHandler(updatedRequest);
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

Future<String?> verifyJwt(String token) async {
  final url = Uri.http(AUTH_API_HOSTNAME, '/auth/validate');
  print(url);
  final response = await http.post(
    url,
    headers: {
      'Authorization': BASIC_AUTHORIZATION,
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

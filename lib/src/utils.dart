import 'package:shelf/shelf.dart';

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

Middleware handleAuth() {
  return (Handler innerHandler) {
    return (Request request) async {
      final authHeader = request.headers['Authorization'];

      if (authHeader != null) {
        if (authHeader.startsWith('Bearer ')) {
          final token = authHeader.substring(7);

          final userId = verifyJwt(token);

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
      if (userId == null || request.headers['user'] != userId) {
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

// todo: Validate token
Future<String> verifyJwt(String token) async {
  return 'userId';
}

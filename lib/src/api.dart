import 'dart:convert';

import '../server.dart';
import 'mongo.dart';

import 'utils.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

final RegExp regexDocumentPath = RegExp(r'^[a-zA-Z0-9_-]+\/[a-z0-9]+$');
final RegExp regexCollectionPath = RegExp(r'^[a-zA-Z0-9_-]+\/?$');

class Api {
  Api({required this.mongo});

  final Mongo mongo;

  Handler get router {
    final router = Router();

    router.post('/setPublicKey', (Request req) async {
      final jsonData = await req.readAsString();
      final userId = req.context['userId'] as String;

      if (jsonData.isEmpty) {
        return Response(HttpStatus.badRequest,
            body: 'Provide a public key as {key: <pub-key>}');
      }

      try {
        final data = json.decode(jsonData) as Map<String, dynamic>;
        if (!data.containsKey('key')) {
          return Response(HttpStatus.badRequest,
              body: 'Provide a public key as {key: <pub-key>}');
        }
        final publicKey = data['key'];

        await mongo.setPublicKey(userId, publicKey);

        return Response.ok(
          'Successfully set public key',
        );
      } on FormatException {
        return Response(HttpStatus.badRequest,
            body: 'Data is not a valid JSON.');
      } catch (e) {
        print(e);
        return Response.internalServerError();
      }
    });

    router.post('/create', (Request req) async {
      final userId = req.context['userId'] as String;
      final jsonData = await req.readAsString();

      if (jsonData.isEmpty) {
        return Response(HttpStatus.badRequest,
            body: 'Provide a project name {name: <project-name>}');
      }

      try {
        final data = json.decode(jsonData) as Map<String, dynamic>;
        if (!data.containsKey('name')) {
          return Response(HttpStatus.badRequest,
              body: 'Provide a project name {name: <project-name>}');
        }
        final name = data['name'];

        await mongo.createProject(userId, name);

        return Response.ok(
          'Successfully set public key',
        );
      } on FormatException {
        return Response(HttpStatus.badRequest,
            body: 'Data is not a valid JSON.');
      } catch (e) {
        print(e);
        return Response.internalServerError();
      }
    });

    final handler =
        Pipeline().addMiddleware(checkAuthorization()).addHandler(router);

    return handler;
  }
}

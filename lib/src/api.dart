import 'dart:convert';

import '../server.dart';

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

        if (await mongo.hasUserKey(userId)) {
          return Response(HttpStatus.badRequest,
              body: 'User already has public key');
        }

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

    router.post('/getPublicKey', (Request req) async {
      final jsonData = await req.readAsString();

      if (jsonData.isEmpty) {
        return Response(HttpStatus.badRequest,
            body: 'Provide an username as {user: <username>}');
      }

      try {
        final data = json.decode(jsonData) as Map<String, dynamic>;
        if (!data.containsKey('user')) {
          return Response(HttpStatus.badRequest,
              body: 'Provide an username as {user: <username>}');
        }
        final userId = data['user'];

        if (!await mongo.hasUserKey(userId)) {
          return Response.ok('');
        }

        final key = await mongo.getPublicKey(userId);

        return Response.ok(
          key,
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
            body: 'Provide a project name and encrypted key');
      }

      try {
        final data = json.decode(jsonData) as Map<String, dynamic>;
        if (!data.containsKey('name') || !data.containsKey('key')) {
          return Response(HttpStatus.badRequest,
              body: 'Provide a project name and encrypted key');
        }
        final name = data['name'] as String;
        if (name.isEmpty || name.contains('/')) {
          return Response(HttpStatus.badRequest, body: 'Invalid project name');
        }

        final key = data['key'] as String;
        if (key.isEmpty) {
          return Response(HttpStatus.badRequest, body: 'Invalid project key');
        }

        if (await mongo.userHasProject(userId, name)) {
          return Response(HttpStatus.badRequest,
              body: 'User already has project named $name');
        }

        final projectId = await mongo.createProject(userId, name, key);
        if (projectId == null) {
          return Response.internalServerError(
              body: 'Something went wrong creating project $name...');
        }

        return Response.ok(projectId);
      } on FormatException {
        return Response(HttpStatus.badRequest,
            body: 'Data is not a valid JSON.');
      } catch (e) {
        print(e);
        return Response.internalServerError();
      }
    });

    router.post('/share', (Request req) async {
      final userId = req.context['userId'] as String;
      final jsonData = await req.readAsString();

      if (jsonData.isEmpty) {
        return Response(HttpStatus.badRequest,
            body: 'Provide: project, user, key');
      }

      try {
        final data = json.decode(jsonData) as Map<String, dynamic>;
        if (!data.containsKey('project') ||
            !data.containsKey('user') ||
            !data.containsKey('key')) {
          return Response(HttpStatus.badRequest,
              body: 'Provide: project, user, key');
        }
        final projectId = data['project'];
        final newUserId = data['user'];
        final encryptedKey = data['key'];

        if (!await mongo.userOwnsProjectId(userId, projectId)) {
          return Response(HttpStatus.badRequest,
              body: 'User does not own this project');
        }

        if (await mongo.userSharedProjectWith(userId, projectId, newUserId)) {
          return Response(HttpStatus.badRequest,
              body: 'User already shared this project with the provided user');
        }

        final result = await mongo.shareProject(
            userId, projectId, newUserId, encryptedKey);
        if (!result) {
          return Response.internalServerError(
              body: 'Something went wrong sharing project...');
        }

        return Response.ok('');
      } on FormatException {
        return Response(HttpStatus.badRequest,
            body: 'Data is not a valid JSON.');
      } catch (e) {
        print(e);
        return Response.internalServerError();
      }
    });

    router.post('/clone', (Request req) async {
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

        if (!await mongo.userHasProject(userId, name)) {
          return Response(HttpStatus.badRequest,
              body: 'No project named $name');
        }

        final projectData = await mongo.getProjectData(userId, name);
        if (projectData == null) {
          return Response.internalServerError(
              body: 'Something went wrong cloning project $name...');
        }

        return Response.ok(
          jsonEncode(projectData),
        );
      } on FormatException {
        return Response(HttpStatus.badRequest,
            body: 'Data is not a valid JSON.');
      } catch (e) {
        print(e);
        return Response.internalServerError();
      }
    });

    router.post('/push', (Request req) async {
      final userId = req.context['userId'] as String;
      return Response.ok("");
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

        if (!await mongo.userHasProject(userId, name)) {
          return Response(HttpStatus.badRequest,
              body: 'No project named $name');
        }

        final projectData = await mongo.getProjectData(userId, name);
        if (projectData == null) {
          return Response.internalServerError(
              body: 'Something went wrong cloning project $name...');
        }

        return Response.ok(
          jsonEncode(projectData),
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

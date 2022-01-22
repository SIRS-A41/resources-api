import 'dart:async';
import 'dart:convert';

import 'package:mongo_dart/mongo_dart.dart';

import '../server.dart';

final RegExp regexDocumentPath = RegExp(r'^[a-zA-Z0-9_-]+\/[a-z0-9]+$');
final RegExp regexCollectionPath = RegExp(r'^[a-zA-Z0-9_-]+\/?$');

class Api {
  Api({
    required this.mongo,
    required this.sftp,
  });

  final Mongo mongo;
  final Sftp sftp;

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

    router.post('/upload', (Request request) async {
      final userId = request.context['userId'] as String;
      final contentType = request.headers['content-type'];
      if (contentType == null) {
        return Response(400, body: 'Missing content-type');
      }

      final mediaType = MediaType.parse(contentType);
      if (mediaType.mimeType != 'multipart/form-data') {
        return Response(400, body: 'Invalid content-type');
      }

      final boundary = mediaType.parameters['boundary'];
      if (boundary == null) {
        return Response(400, body: 'Missing boundary');
      }

      final payload = request.read();
      final parts = MimeMultipartTransformer(boundary).bind(payload);
      // .where((part) {
      // return part.headers['content-type'] == 'application/octet-stream';
      // });

      final partsIterator = StreamIterator(parts);
      String? projectId;
      String? iv;
      String? signature;
      final fileBytes = <int>[];
      File? file;
      while (await partsIterator.moveNext()) {
        final part = partsIterator.current;

        if (!part.headers.containsKey('content-disposition')) {
          return Response(400, body: 'Missing content-disposition');
        }

        final header = HeaderValue.parse(part.headers['content-disposition']!);
        if (!header.parameters.containsKey('name')) {
          return Response(400, body: 'Missing form entry name');
        }
        final name = header.parameters['name'];
        switch (name) {
          case 'project':
            projectId = '';
            final lines = part.transform(utf8.decoder);
            await for (var line in lines) {
              projectId = '$projectId$line';
            }
            break;
          case 'iv':
            iv = '';
            final lines = part.transform(utf8.decoder);
            await for (var line in lines) {
              iv = '$iv$line';
            }
            break;
          case 'signature':
            signature = '';
            final lines = part.transform(utf8.decoder);
            await for (var line in lines) {
              signature = '$signature$line';
            }
            break;
          case 'file':
            final chunksIterator = StreamIterator(part);

            while (await chunksIterator.moveNext()) {
              final chunk = chunksIterator.current;
              fileBytes.addAll(chunk);
            }
            file = File('');
            break;
          default:
            return Response(400, body: 'Invalid parameter $name');
        }
        if (file != null &&
            iv != null &&
            signature != null &&
            projectId != null) {
          break;
        }
      }
      if (signature == null || signature.isEmpty) {
        return Response(400, body: 'Invalid signature');
      }
      if (iv == null || iv.isEmpty) {
        return Response(400, body: 'Invalid AES iv');
      }
      if (projectId == null || projectId.isEmpty) {
        return Response(400, body: 'Invalid projectId');
      }
      if (fileBytes.isEmpty) {
        return Response(400, body: 'Invalid file');
      }

      final publicKey = await mongo.getKey(userId);
      if (publicKey == null) {
        return Response.forbidden('User not allowed');
      }
      final hashHex = verifySignature(fileBytes, signature, publicKey);
      if (hashHex == null) return Response.forbidden('Invalid file signature');

      final result = await sftp.writeFile(hashHex, fileBytes);
      if (!result) {
        Response.internalServerError(body: 'Failed to save project files');
      }

      await mongo.newPush(
        user: userId,
        project: projectId,
        signature: signature,
        iv: iv,
        hash: hashHex,
      );

      return Response.ok(hashHex);
    });

    final handler =
        Pipeline().addMiddleware(checkAuthorization()).addHandler(router);

    return handler;
  }
}

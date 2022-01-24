import 'dart:async';
import 'dart:convert';

import '../server.dart';

class Api {
  Api({
    required this.mongo,
    required this.sftp,
  });

  final Mongo mongo;
  final Sftp sftp;

  Handler get router {
    final router = Router();

    router.get('/projects', (Request req) async {
      final userId = req.context['userId'] as String;

      try {
        final projects = await mongo.getProjects(userId);

        return Response.ok(json.encode({'projects': projects}));
      } on FormatException {
        return Response(HttpStatus.badRequest,
            body: 'Data is not a valid JSON.');
      } catch (e) {
        print(e);
        return Response.internalServerError();
      }
    });
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
        var name = data['name'] as String;
        if (name.isEmpty || name.contains('/')) {
          return Response(HttpStatus.badRequest, body: 'Invalid project name');
        }
        name = '$userId/$name';

        final key = data['key'] as String;
        if (key.isEmpty) {
          return Response(HttpStatus.badRequest, body: 'Invalid project key');
        }

        if (await mongo.userHasProject(userId, name)) {
          return Response(HttpStatus.badRequest,
              body: 'User already has project named $name');
        }

        final result = await sftp.createProject(name);
        if (!result) {
          return Response.internalServerError(
              body: 'Something went wrong creating project $name...');
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
        String name = data['name'];
        if (!name.contains('/')) {
          name = '$userId/$name';
        }

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

    router.post('/versions', (Request req) async {
      final userId = req.context['userId'] as String;
      final jsonData = await req.readAsString();

      if (jsonData.isEmpty) {
        return Response(HttpStatus.badRequest, body: 'Provide a project id');
      }

      try {
        final data = json.decode(jsonData) as Map<String, dynamic>;
        if (!data.containsKey('project')) {
          return Response(HttpStatus.badRequest, body: 'Provide a project id');
        }
        final project = data['project'];

        final projectData = await mongo.getProjectDataById(userId, project);
        if (projectData == null) {
          return Response(HttpStatus.badRequest,
              body: 'No project with this id');
        }

        final name = projectData['name'];
        if (name == null) {
          return Response.internalServerError(
              body: 'Something went wrong verifying project name');
        }

        final result = await mongo.projectVersions(name);
        return Response.ok(json.encode({'history': result}));
      } on FormatException {
        return Response(HttpStatus.badRequest,
            body: 'Data is not a valid JSON.');
      } catch (e) {
        print(e);
        return Response.internalServerError();
      }
    });

    router.post('/pull', (Request req) async {
      final userId = req.context['userId'] as String;
      final jsonData = await req.readAsString();

      if (jsonData.isEmpty) {
        return Response(HttpStatus.badRequest, body: 'Provide a project id');
      }

      try {
        final data = json.decode(jsonData) as Map<String, dynamic>;
        if (!data.containsKey('project')) {
          return Response(HttpStatus.badRequest, body: 'Provide a project id');
        }
        final project = data['project'];
        String? version = data['version'];

        final projectData = await mongo.getProjectDataById(userId, project);
        if (projectData == null) {
          return Response(HttpStatus.badRequest,
              body: 'No project with this id');
        }

        final name = projectData['name'];
        if (name == null) {
          return Response.internalServerError(
              body: 'Something went wrong verifying project name');
        }

        Map<String, dynamic>? commit;
        if (version == null) {
          commit = await mongo.latestVersion(name);
          if (commit == null) {
            return Response(HttpStatus.badRequest,
                body: 'Project has no commits');
          }
          version = commit['version'];
        } else {
          commit = await mongo.getVersion(name, version);
          if (commit == null) {
            return Response(HttpStatus.badRequest,
                body: 'Project has no version $version');
          }
        }
        final signature = commit['signature'];
        final iv = commit['iv'];
        final user = commit['user'];

        final file = await sftp.readFile(name, version!);
        if (file == null) {
          return Response.internalServerError(
              body: 'Something went wrong reading files from server');
        }

        return Response(
          HttpStatus.partialContent,
          body: file,
          headers: {'X-signature': signature, 'X-user': user, 'X-iv': iv},
        );
      } on FormatException {
        return Response(HttpStatus.badRequest,
            body: 'Data is not a valid JSON.');
      } catch (e) {
        print(e);
        return Response.internalServerError();
      }
    });

    router.post('/hasCommit', (Request req) async {
      final userId = req.context['userId'] as String;
      final jsonData = await req.readAsString();

      if (jsonData.isEmpty) {
        return Response(HttpStatus.badRequest,
            body: 'Provide a project id and commit version');
      }

      try {
        final data = json.decode(jsonData) as Map<String, dynamic>;
        if (!data.containsKey('version') || !data.containsKey('project')) {
          return Response(HttpStatus.badRequest,
              body: 'Provide a project id and commit version');
        }
        final project = data['project'];
        final version = data['version'];

        final projectData = await mongo.getProjectDataById(userId, project);
        if (projectData == null) {
          return Response(HttpStatus.badRequest,
              body: 'No project with this id');
        }

        final name = projectData['name'];
        if (name == null) {
          return Response.internalServerError(
              body: 'Something went wrong verifying project name');
        }

        final result = await mongo.projectHasVersion(name, version);
        return Response.ok(result.toString());
      } on FormatException {
        return Response(HttpStatus.badRequest,
            body: 'Data is not a valid JSON.');
      } catch (e) {
        print(e);
        return Response.internalServerError();
      }
    });

    router.post('/push', (Request request) async {
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
      String? version;
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
          case 'version':
            version = '';
            final lines = part.transform(utf8.decoder);
            await for (var line in lines) {
              version = '$version$line';
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
            version != null &&
            signature != null &&
            projectId != null) {
          break;
        }
      }
      if (version == null || version.isEmpty) {
        return Response(400, body: 'Invalid version');
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
      final projectName =
          (await mongo.getProjectDataById(userId, projectId))?['name'];
      if (projectName == null) {
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

      if (await mongo.projectHasVersion(projectName, version)) {
        return Response(400, body: 'Project already has commit $version');
      }

      final result = await sftp.writeFile(projectName, version, fileBytes);
      if (!result) {
        return Response.internalServerError(
            body: 'Failed to save project files');
      }

      await mongo.newPush(
        user: userId,
        project: projectId,
        signature: signature,
        iv: iv,
        version: version,
      );

      return Response.ok(hashHex);
    });

    final handler =
        Pipeline().addMiddleware(checkAuthorization()).addHandler(router);

    return handler;
  }
}

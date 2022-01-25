import 'dart:convert';

import 'package:resources_api/server.dart';

const MONGO_IP = Env.mongoIp;
const LOCAL_AUTH_IP = Env.localAuthIp;
const SFTP_IP = Env.sftpIp;
const CLIENT_ID = Env.clientId;
const CLIENT_SECRET = Env.clientSecret;

late HttpServer server;
late Mongo mongo;
late Sftp sftp;
late Router app;
late String clientBase64;

void main(List<String> arguments) async {
  var bytes = utf8.encode('$CLIENT_ID:$CLIENT_SECRET');
  clientBase64 = base64.encode(bytes);

  mongo = Mongo('mongodb://$MONGO_IP:27017');
  await mongo.init();

  sftp = Sftp(host: SFTP_IP);
  await sftp.init();

  app = Router();
  setupRequests();

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(handleCors())
      .addMiddleware(handleAuth(LOCAL_AUTH_IP, clientBase64))
      .addMiddleware(logUserRequests())
      .addHandler(app);
  server = await serve(
    handler,
    InternetAddress.anyIPv4,
    8444,
    securityContext: getSecurityContext(),
  );
  // Enable content compression
  server.autoCompress = true;

  print('Serving at https://${server.address.host}:${server.port}');
}

void setupRequests() {
  app.mount('/resources/', Api(mongo: mongo, sftp: sftp).router);

  app.get(
    '/hello',
    (Request request) async {
      return Response.ok('world');
    },
  );
}

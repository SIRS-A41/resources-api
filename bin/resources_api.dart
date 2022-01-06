import 'package:auth_api/server.dart';

late HttpServer server;
late Mongo mongo;
late Router app;
late String clientBase64;

void main(List<String> arguments) async {
  mongo = Mongo('mongodb://localhost:27017');
  await mongo.init();

  app = Router();
  setupRequests();

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(handleCors())
      .addMiddleware(handleAuth())
      .addMiddleware(logUserRequests())
      .addHandler(app);
  server = await serve(
    handler,
    InternetAddress.anyIPv4,
    8001,
  );
  // Enable content compression
  server.autoCompress = true;

  print('Serving at http://${server.address.host}:${server.port}');
}

void setupRequests() {
  app.mount('/resources/', Api(mongo: mongo).router);

  app.get(
    '/hello',
    (Request request) async {
      return Response.ok('world');
    },
  );
}

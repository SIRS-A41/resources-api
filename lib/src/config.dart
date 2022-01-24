import 'package:envify/envify.dart';

part 'config.g.dart';

@Envify()
abstract class Env {
  static const mongoIp = _Env.mongoIp;
  static const localAuthIp = _Env.localAuthIp;
  static const sftpIp = _Env.sftpIp;
  static const clientId = _Env.clientId;
  static const clientSecret = _Env.clientSecret;
}

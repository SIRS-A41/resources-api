import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

class Sftp {
  late SftpClient sftp;
  final String host;
  final int port;

  Sftp({required this.host, this.port = 22});

  Future<void> init() async {
    final client = SSHClient(
      await SSHSocket.connect(host, port),
      username: 'sirs',
      onPasswordRequest: () => '123123',
    );
    sftp = await client.sftp();
  }

  Future<bool> createProject(String project) async {
    try {
      await sftp.mkdir(project.split('/').first);
      await sftp.mkdir(project);
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> writeFile(
      String project, String filename, List<int> fileBytes) async {
    try {
      final file = await sftp.open('$project/$filename',
          mode: SftpFileOpenMode.create | SftpFileOpenMode.write);
      await file.writeBytes(Uint8List.fromList(fileBytes));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Stream<Uint8List>?> readFile(String project, String filename) async {
    try {
      final file = await sftp.open('$project/$filename');
      return file.read();
    } catch (e) {
      return null;
    }
  }
}

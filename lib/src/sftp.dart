import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

class Sftp {
  late SftpClient sftp;
  final String host;
  final int port;

  Sftp({required this.host, this.port = 22}) {}

  Future<void> init() async {
    final client = SSHClient(
      await SSHSocket.connect(host, port),
      username: 'sirs',
      onPasswordRequest: () => '123123',
    );
    sftp = await client.sftp();
  }

  Future<bool> writeFile(
      String project, String filename, List<int> fileBytes) async {
    try {
      await sftp.mkdir(project.split('/').first);
      await sftp.mkdir(project);
      final file = await sftp.open('$project/$filename',
          mode: SftpFileOpenMode.create | SftpFileOpenMode.write);
      await file.writeBytes(Uint8List.fromList(fileBytes));
      return true;
    } catch (e) {
      return false;
    }
  }
}

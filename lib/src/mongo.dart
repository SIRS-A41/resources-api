import 'package:mongo_dart/mongo_dart.dart';

typedef MongoFunction = Function(Db db);

class Mongo {
  late Db test;
  late Db db;
  late Db projects;
  late Db versions;
  late DbCollection keys;
  late String mongoUrl;

  Mongo(this.mongoUrl)
      : test = Db('$mongoUrl/test'),
        db = Db('$mongoUrl/db'),
        projects = Db('$mongoUrl/projects'),
        versions = Db('$mongoUrl/projects-versions');

  Future<void> init() async {
    await test.open();
    await db.open();
    await projects.open();
    await versions.open();
    print('Connected to database: $mongoUrl');
    keys = test.collection('public-keys');
  }

  Future<bool> hasUserKey(String userId) async {
    final key = await keys.findOne(where.eq('userId', userId));
    return key != null;
  }

  Future<void> setPublicKey(String userId, String publicKey) async {
    await keys.insertOne({
      'userId': userId,
      'key': publicKey,
    });
  }

  Future<String?> getPublicKey(String userId) async {
    final result = await keys.findOne(where.eq('userId', userId));
    if (result == null) return null;

    return result['key'];
  }

  Future<bool> userHasProject(String userId, String name,
      [String? owner]) async {
    final userProjects = projects.collection(userId);
    final result = await userProjects.findOne(where.eq('name', name));
    return result != null;
  }

  Future<bool> userHasProjectId(String userId, String projectId) async {
    final userProjects = projects.collection(userId);
    final result =
        await userProjects.findOne(where.eq('_id', ObjectId.parse(projectId)));
    return result != null;
  }

  Future<bool> userOwnsProjectId(String userId, String projectId) async {
    final userProjects = projects.collection(userId);
    final result =
        await userProjects.findOne(where.eq('_id', ObjectId.parse(projectId)));
    if (result != null) {
      final projectName = result['name'] as String;
      return _getProjectOwner(projectName) == userId;
    } else {
      return false;
    }
  }

  String _getProjectOwner(String projectName) => projectName.split('/').first;

  Future<bool> userSharedProjectWith(
      String userId, String projectId, String newUserId) async {
    final userProjects = projects.collection(userId);
    final result =
        await userProjects.findOne(where.eq('_id', ObjectId.parse(projectId)));
    if (result == null) return false;

    final sharedWith = List<String>.from((result['shared'] ?? []));
    return sharedWith.contains(newUserId);
  }

  String get now => '${DateTime.now().millisecondsSinceEpoch ~/ 1000}';

  Future<bool> shareProject(String userId, String projectId, String newUserId,
      String encryptedKey) async {
    final result = await getProjectDataById(userId, projectId);
    if (result == null) return false;

    final newUserProjects = projects.collection(newUserId);
    await newUserProjects.insertOne(
        {'name': result['name'], 'key': encryptedKey, 'created_at': now});

    final userProjects = projects.collection(userId);
    final newShared = List<String>.from(result['shared'] ?? [])..add(newUserId);

    await userProjects.updateOne(where.eq('_id', ObjectId.parse(projectId)),
        modify.set('shared', newShared));

    return true;
  }

  Future<String?> createProject(
      String userId, String name, String encryptedKey) async {
    final userProjects = projects.collection(userId);
    final result = await userProjects.insertOne({
      'name': name,
      'key': encryptedKey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'shared': [],
    });
    if (result.document == null) return null;
    return (result.document!['_id'] as ObjectId).$oid;
  }

  Future<Map<String, String>?> getProjectData(
      String userId, String name) async {
    final userProjects = projects.collection(userId);
    final result = await userProjects.findOne(where.eq('name', name));

    final encryptedKey = result!['key'];
    final id = (result['_id'] as ObjectId).$oid;

    return {
      'key': encryptedKey,
      'id': id,
    };
  }

  Future<Map<String, dynamic>?> getProjectDataById(
      String userId, String projectId) async {
    final userProjects = projects.collection(userId);
    final result =
        await userProjects.findOne(where.eq('_id', ObjectId.parse(projectId)));

    final name = result!['name'];
    final sharedWith = result['shared'];
    final encryptedKey = result['key'];
    final id = (result['_id'] as ObjectId).$oid;

    return {
      'name': name,
      'shared': sharedWith,
      'key': encryptedKey,
      'id': id,
    };
  }

  Future<Map<String, dynamic>?> getVersion(
      String projectName, String version) async {
    final project = versions.collection(projectName);
    final result = await project.findOne(where.eq('version', version));
    return result;
  }

  Future<Map<String, dynamic>?> latestVersion(String projectName) async {
    final project = versions.collection(projectName);
    final result =
        await project.findOne(where.sortBy('timestamp', descending: true));
    return result;
  }

  Future<bool> projectHasVersion(String projectName, String version) async {
    final project = versions.collection(projectName);
    final result = await project.findOne(where.eq('version', version));
    return result != null;
  }

  Future<List<Map<String, dynamic>>> getProjects(String userId) async {
    final userProjects = projects.collection(userId);
    final result = (await userProjects
            .find(where.sortBy('created_at', descending: true))
            .toList())
        .map((Map<String, dynamic> data) {
      String name = data['name'];
      if (name.split('/').first == userId) name = name.split('/').last;
      return <String, dynamic>{
        'name': name,
        'created_at': data['created_at'],
        'shared': List<String>.from(data['shared'] ?? []).join(', ')
      };
    });
    return result.toList();
  }

  Future<List<Map<String, dynamic>>> projectVersions(String projectName) async {
    final project = versions.collection(projectName);
    final result = (await project
            .find(where.sortBy('timestamp', descending: true))
            .toList())
        .map((Map<String, dynamic> data) => {
              'user': data['user'],
              'version': data['version'],
              'timestamp': data['timestamp']
            });
    return result.toList();
  }

  Future<String?> getKey(String userId) async {
    final key = await keys.findOne(where.eq('userId', userId));
    return key?['key'];
  }

  Future<String?> newPush(
      {required String user,
      required String project,
      required String version,
      required String mac,
      required String macIv,
      required String signature,
      required String iv}) async {
    final result = await getProjectDataById(user, project);
    if (result == null) return null;

    final projectName = result['name'] as String;

    return await addVersion(
      userId: user,
      projectName: projectName,
      iv: iv,
      mac: mac,
      macIv: macIv,
      signature: signature,
      version: version,
    );
  }

  Future<String> addVersion({
    required String userId,
    required String projectName,
    required String signature,
    required String mac,
    required String macIv,
    required String iv,
    required String version,
  }) async {
    final project = versions.collection(projectName);
    final result = await project.insertOne({
      'user': userId,
      'iv': iv,
      'signature': signature,
      'mac': mac,
      'mac-iv': macIv,
      'timestamp': now,
      'version': version,
    });
    return (result.document!['_id'] as ObjectId).$oid;
  }
}

import 'package:auth_api/src/encrypt.dart';
import 'package:mongo_dart/mongo_dart.dart';

typedef MongoFunction = Function(Db db);

class Mongo {
  late Db test;
  late Db db;
  late Db projects;
  late DbCollection keys;
  late String mongoUrl;

  Mongo(this.mongoUrl)
      : test = Db('$mongoUrl/test'),
        db = Db('$mongoUrl/db'),
        projects = Db('$mongoUrl/projects');

  Future<void> init() async {
    await test.open();
    await db.open();
    await projects.open();
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

  Future<bool> userSharedProjectWith(
      String userId, String projectId, String newUserId) async {
    final userProjects = projects.collection(userId);
    final result =
        await userProjects.findOne(where.eq('_id', ObjectId.parse(projectId)));
    if (result == null) return false;

    final sharedWith = List<String>.from((result['shared'] ?? []));
    return sharedWith.contains(newUserId);
  }

  Future<bool> shareProject(String userId, String projectId, String newUserId,
      String encryptedKey) async {
    final result = await getProjectDataById(userId, projectId);
    if (result == null) return false;

    final newUserProjects = projects.collection(newUserId);
    await newUserProjects.insertOne({
      'name': "$userId/${result['name']}",
      'key': encryptedKey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000
    });

    final userProjects = projects.collection(userId);
    final newShared = List<String>.from(result['shared'] ?? [])..add(newUserId);

    await userProjects.updateOne(where.eq('_id', ObjectId.parse(projectId)),
        modify.set('shared', newShared));

    return true;
  }

  Future<Map<String, String>?> createProject(String userId, String name) async {
    final publicKey = await getKey(userId);
    if (publicKey == null) return null;

    final key = generateKey();
    final encryptedKey = encryptPublic(publicKey, key);

    final userProjects = projects.collection(userId);
    final result = await userProjects.insertOne({
      'name': name,
      'key': encryptedKey,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'shared': [],
    });
    return {
      'key': encryptedKey,
      'id': (result.document!['_id'] as ObjectId).$oid,
    };
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

  Future<String?> getKey(String userId) async {
    final key = await keys.findOne(where.eq('userId', userId));
    return key?['key'];
  }
}

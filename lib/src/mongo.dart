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

  Future<bool> userHasProject(String userId, String name) async {
    final userProjects = projects.collection(userId);
    final result = await userProjects.findOne(where.eq('name', name));
    return result != null;
  }

  Future<Map<String, String>?> createProject(String userId, String name) async {
    final publicKey = await getKey(userId);
    if (publicKey == null) return null;

    final key = generateKey();
    final encryptedKey = encryptPublic(publicKey, key);

    final userProjects = projects.collection(userId);
    final result = await userProjects.insertOne({
      'name': name,
      'owner': userId,
      'keys': {userId: encryptedKey},
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000
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

    final encryptedKey = result!['keys'][userId];
    final id = (result['_id'] as ObjectId).$oid;

    return {
      'key': encryptedKey,
      'id': id,
    };
  }

  Future<String?> getKey(String userId) async {
    final key = await keys.findOne(where.eq('userId', userId));
    return key?['key'];
  }
}

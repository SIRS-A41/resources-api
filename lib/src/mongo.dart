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

  Future<bool> userHasProject(String userId, String name) async {
    final userProjects = projects.collection(userId);
    final result = await userProjects.findOne(where.eq('name', name));
    return result != null;
  }

  Future<void> createProject(String userId, String name) async {
    final userProjects = projects.collection(userId);
    await userProjects.insertOne({
      'name': name,
      'owner': userId,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000
    });
  }
}

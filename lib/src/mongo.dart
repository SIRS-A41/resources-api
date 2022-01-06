import 'package:mongo_dart/mongo_dart.dart';

typedef MongoFunction = Function(Db db);

class Mongo {
  late Db test;
  late Db db;
  late DbCollection keys;
  late String mongoUrl;

  Mongo(this.mongoUrl)
      : test = Db('$mongoUrl/test'),
        db = Db('$mongoUrl/db');

  Future<void> init() async {
    await test.open();
    await db.open();
    print('Connected to database: $mongoUrl');
    keys = test.collection('public-keys');
  }

  Future<bool> hasUserKey(String userId) async {
    final key = await keys.findOne(where.eq('userId', userId));
    return key != null;
  }

  Future<void> setPublicKey(String userId, String publicKey) async {
    if (await hasUserKey(userId)) {
      await keys.replaceOne(where.eq('userId', userId), {
        'userId': userId,
        'key': publicKey,
      });
    } else {
      await keys.insertOne({
        'userId': userId,
        'key': publicKey,
      });
    }
  }
}

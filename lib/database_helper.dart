import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'events.dart'; // This should point to your Event model class

class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;
  static const String dbName = 'company_calendar.db';

  Future<Database> get database async {
    _database ??= await initializeDB();
    return _database!;
  }

  Future<Database> initializeDB() async {
    print("Initializing database...");
    String dbPath = join(await getDatabasesPath(),
        dbName); // Append dbName to the directory path
    return await openDatabase(
      dbPath,
      onCreate: (database, version) async {
        await database.execute(
          "CREATE TABLE IF NOT EXISTS events("
          "id INTEGER PRIMARY KEY AUTOINCREMENT,"
          "title TEXT NOT NULL,"
          "isPrivate INTEGER,"
          "isAllDay INTEGER,"
          "date INTEGER,"
          "endDate INTEGER," // Added endDate to store the end date of the event
          "startTime TEXT,"
          "endTime TEXT,"
          "flagUrl TEXT,"
          "username TEXT NOT NULL"
          ");",
        );
      },
      version: 1,
    );
  }

  Future<void> deleteDB() async {
    String path = join(await getDatabasesPath(), dbName);
    await deleteDatabase(path);
  }

  Future<int> insertEvent(Event event) async {
    final db = await database;
    return await db.insert('events', event.toMap());
  }

  Future<List<Event>> fetchEvents(
      {DateTime? from, DateTime? to, bool? includePrivate}) async {
    final db = await database;
    List<Map<String, dynamic>> queryResult;

    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (from != null && to != null) {
      whereClauses.add("date >= ? AND (endDate <= ? OR endDate IS NULL)");
      whereArgs.add(from.millisecondsSinceEpoch);
      whereArgs.add(to.millisecondsSinceEpoch);
    }

    if (includePrivate != null) {
      whereClauses.add("isPrivate = ?");
      whereArgs.add(includePrivate ? 1 : 0);
    }

    if (whereClauses.isNotEmpty) {
      queryResult = await db.query(
        'events',
        where: whereClauses.join(" AND "),
        whereArgs: whereArgs,
      );
    } else {
      queryResult = await db.query('events');
    }

    return queryResult.map((e) => Event.fromMap(e)).toList();
  }

  Future<int> updateEvent(Event event) async {
    final db = await database;
    return db.update(
      'events',
      event.toMap(),
      where: "id = ?",
      whereArgs: [event.id],
    );
  }

  Future<void> deleteEvent(int id) async {
    final db = await database;
    await db.delete('events', where: "id = ?", whereArgs: [id]);
  }
}

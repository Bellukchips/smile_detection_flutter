import 'package:face_detection_local/models/access_log.dart';
import 'package:face_detection_local/models/user.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('face_recognition.db');
    return _database!;
  }

  /// Initialize database at given path.
  ///
  /// Path is relative to application's databases directory.
  ///
  /// Database will be created if it doesn't exist.
  ///
  /// [_createDB] will be called if database version is 1.
  ///
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  /// Create database schema for face recognition application.
  ///
  /// Database contains two tables: users and access_logs.
  ///
  /// users table contains user's information: id, name, employee_id,
  /// department, face_embedding, photo_path, created_at and is_active.
  ///
  /// access_logs table contains logs of user's access: id, user_id,
  /// user_name, action, confidence_score, photo_path, timestamp and reason.
  ///
  /// Index is created for employee_id, timestamp and user_id columns to
  /// improve query performance.
  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const realType = 'REAL';

    await db.execute('''
      CREATE TABLE users (
        id $idType,
        name $textType,
        employee_id $textType UNIQUE,
        department $textType,
        face_embedding TEXT NOT NULL,
        photo_path $textType,
        created_at $textType,
        is_active $intType
      )
    ''');

    await db.execute('''
      CREATE TABLE access_logs (
        id $idType,
        user_id TEXT,
        user_name TEXT,
        action $textType,
        confidence_score $realType,
        photo_path TEXT,
        timestamp $textType,
        reason TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_employee_id ON users(employee_id)');
    await db.execute('CREATE INDEX idx_timestamp ON access_logs(timestamp)');
    await db.execute('CREATE INDEX idx_user_id ON access_logs(user_id)');
  }

  /// Insert a user into the database.
  ///
  /// Returns the id of the inserted user.
  ///
  /// Throws a [SqliteException] if the user already exists in the database.
  Future<int> insertUser(UserModel user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  /// Returns a user with given id from the database.
  ///
  /// Returns null if no user with given id exists in the database.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<UserModel?> getUserById(String id) async {
    final db = await database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);

    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  /// Returns a user with given employee id from the database.
  ///
  /// Returns null if no user with given employee id exists in the database.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<UserModel?> getUserByEmployeeId(String employeeId) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );

    if (maps.isEmpty) return null;
    return UserModel.fromMap(maps.first);
  }

  /// Returns all users from the database.
  ///
  /// If [activeOnly] is true, only active users are returned.
  ///
  /// Throws a [SqliteException] if the query fails.

  Future<List<UserModel>> getAllUsers({bool activeOnly = true}) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name ASC',
    );

    return maps.map((map) => UserModel.fromMap(map)).toList();
  }

  /// Update a user in the database.
  ///
  /// Returns the number of affected rows.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<int> updateUser(UserModel user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /// Delete a user with given id from the database.
  ///
  /// Returns the number of affected rows.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<int> deleteUser(String id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns the number of active users in the database.
  ///
  /// If the query fails, returns 0.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<int> getUserCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM users WHERE is_active = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Insert an access log into the database.
  ///
  /// Returns the id of the inserted log.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<int> insertAccessLog(AccessLogModel log) async {
    final db = await database;
    return await db.insert('access_logs', log.toMap());
  }

  /// Returns a list of access logs from the database.
  ///
  /// The list is ordered by timestamp in descending order.
  ///
  /// If [limit] is not null, the list is limited to [limit] items.
  ///
  /// If [userId] is not null, the list is filtered to only include logs
  /// from the user with given id.
  ///
  /// If [startDate] and [endDate] are not null, the list is filtered to
  /// only include logs with timestamps between [startDate] and [endDate].
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<List<AccessLogModel>> getAccessLogs({
    int limit = 50,
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClause = 'user_id = ?';
      whereArgs.add(userId);
    }

    if (startDate != null && endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp BETWEEN ? AND ?';
      whereArgs.addAll([
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ]);
    }

    final maps = await db.query(
      'access_logs',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp DESC',
      limit: limit,
    );

    return maps.map((map) => AccessLogModel.fromMap(map)).toList();
  }

  /// Returns a map containing the total number of access logs, the number of granted access logs, and the number of denied access logs.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<Map<String, dynamic>> getAccessStats() async {
    final db = await database;

    final total = await db.rawQuery(
      'SELECT COUNT(*) as count FROM access_logs',
    );
    final granted = await db.rawQuery(
      "SELECT COUNT(*) as count FROM access_logs WHERE action = 'granted'",
    );
    final denied = await db.rawQuery(
      "SELECT COUNT(*) as count FROM access_logs WHERE action = 'denied'",
    );

    return {
      'total': Sqflite.firstIntValue(total) ?? 0,
      'granted': Sqflite.firstIntValue(granted) ?? 0,
      'denied': Sqflite.firstIntValue(denied) ?? 0,
    };
  }

  /// Clears old access logs from the database, keeping logs from the last [daysToKeep] days.
  ///
  /// Throws a [SqliteException] if the query fails.
  ///
  /// Returns the number of deleted rows.
  Future<int> clearOldLogs(int daysToKeep) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    return await db.delete(
      'access_logs',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  /// Closes the database connection.
  ///
  /// You should call this method when you are done using the database service.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}

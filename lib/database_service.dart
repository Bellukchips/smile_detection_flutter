import 'package:face_detection_local/models/access_log.dart';
import 'package:face_detection_local/models/user.dart';
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database?> get database async {
    if (_database != null) {
      Logger().e('Using existing database');
      return _database;
    }

    Logger().i('Initializing new database');
    _database = await _initDB('face_recognition.db');
    return _database;
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
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      Logger().i('📂 Database path: $path');

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDB,
        onOpen: (db) {
          Logger().i('✅ Database opened successfully');
        },
      );
    } catch (e) {
      Logger().e('❌ Error initializing database: $e');
      rethrow;
    }
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
    Logger().i('Creating database...');
    try {
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

      Logger().i('Created users table');

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

      Logger().i('Created access_logs table');

      await db.execute('CREATE INDEX idx_employee_id ON users(employee_id)');
      await db.execute('CREATE INDEX idx_timestamp ON access_logs(timestamp)');
      await db.execute('CREATE INDEX idx_user_id ON access_logs(user_id)');
    } catch (e) {
      Logger().e('❌ Error creating database: $e');
      rethrow;
    }
  }

  /// Insert a user into the database.
  ///
  /// Returns the id of the inserted user.
  ///
  /// Throws a [SqliteException] if the user already exists in the database.
  Future<int> insertUser(UserModel user) async {
    try {
      Logger().i('💾 Inserting user: ${user.name}');

      final db = await database;
      final userMap = user.toMap();

      Logger().i('📋 User data:');
      Logger().i('   ID: ${userMap['id']}');
      Logger().i('   Name: ${userMap['name']}');
      Logger().i('   Employee ID: ${userMap['employee_id']}');
      Logger().i('   Department: ${userMap['department']}');
      Logger().i('   Photo path: ${userMap['photo_path']}');
      Logger().i('   Embedding length: ${user.faceEmbedding.length}');
      Logger().i('   Created at: ${userMap['created_at']}');
      Logger().i('   Is active: ${userMap['is_active']}');

      // Validate data before insert
      if (user.id.isEmpty) {
        throw Exception('User ID cannot be empty');
      }
      if (user.name.isEmpty) {
        throw Exception('User name cannot be empty');
      }
      if (user.employeeId.isEmpty) {
        throw Exception('Employee ID cannot be empty');
      }
      if (user.faceEmbedding.isEmpty) {
        throw Exception('Face embedding cannot be empty');
      }

      final result = await db!.insert(
        'users',
        userMap,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      Logger().i('✅ User inserted successfully with row ID: $result');
      return result;
    } catch (e) {
      Logger().i('❌ Error inserting user: $e');
      Logger().i('   Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Returns a user with given id from the database.
  ///
  /// Returns null if no user with given id exists in the database.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<UserModel?> getUserById(String id) async {
    try {
      final db = await database;
      final maps = await db!.query('users', where: 'id = ?', whereArgs: [id]);

      if (maps.isEmpty) {
        Logger().w('⚠️ User not found with ID: $id');
        return null;
      }

      Logger().w('✅ User found: ${maps.first['name']}');
      return UserModel.fromMap(maps.first);
    } catch (e) {
      Logger().w('❌ Error getting user by ID: $e');
      rethrow;
    }
  }

  /// Returns a user with given employee id from the database.
  ///
  /// Returns null if no user with given employee id exists in the database.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<UserModel?> getUserByEmployeeId(String employeeId) async {
    try {
      Logger().i('🔍 Searching user with employee ID: $employeeId');

      final db = await database;
      final maps = await db!.query(
        'users',
        where: 'employee_id = ?',
        whereArgs: [employeeId],
      );

      if (maps.isEmpty) {
        Logger().i(
          '✅ No user found with employee ID: $employeeId (OK to register)',
        );
        return null;
      }

      Logger().w('⚠️ User already exists: ${maps.first['name']}');
      return UserModel.fromMap(maps.first);
    } catch (e) {
      Logger().e('❌ Error getting user by employee ID: $e');
      rethrow;
    }
  }

  /// Returns all users from the database.
  ///
  /// If [activeOnly] is true, only active users are returned.
  ///
  /// Throws a [SqliteException] if the query fails.

  Future<List<UserModel>> getAllUsers({bool activeOnly = true}) async {
    try {
      Logger().i('📋 Getting all users (active only: $activeOnly)');

      final db = await database;
      final maps = await db!.query(
        'users',
        where: activeOnly ? 'is_active = ?' : null,
        whereArgs: activeOnly ? [1] : null,
        orderBy: 'name ASC',
      );

      Logger().i('✅ Found ${maps.length} user(s)');
      return maps.map((map) => UserModel.fromMap(map)).toList();
    } catch (e) {
      Logger().e('❌ Error getting all users: $e');
      rethrow;
    }
  }

  /// Update a user in the database.
  ///
  /// Returns the number of affected rows.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<int> updateUser(UserModel user) async {
    try {
      Logger().i('🔄 Updating user: ${user.name}');

      final db = await database;
      final result = await db!.update(
        'users',
        user.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );

      Logger().i('✅ User updated successfully');
      return result;
    } catch (e) {
      Logger().i('❌ Error updating user: $e');
      rethrow;
    }
  }

  /// Delete a user with given id from the database.
  ///
  /// Returns the number of affected rows.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<int> deleteUser(String id) async {
    try {
      Logger().i('🗑️ Deleting user with ID: $id');

      final db = await database;
      final result = await db!.delete(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );

      Logger().i('✅ User deleted successfully');
      return result;
    } catch (e) {
      Logger().e('❌ Error deleting user: $e');
      rethrow;
    }
  }

  /// Returns the number of active users in the database.
  ///
  /// If the query fails, returns 0.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<int> getUserCount() async {
    try {
      final db = await database;
      final result = await db!.rawQuery(
        'SELECT COUNT(*) as count FROM users WHERE is_active = 1',
      );

      final count = Sqflite.firstIntValue(result) ?? 0;
      Logger().i('📊 Total active users: $count');
      return count;
    } catch (e) {
      Logger().e('❌ Error getting user count: $e');
      return 0;
    }
  }

  /// Insert an access log into the database.
  ///
  /// Returns the id of the inserted log.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<int> insertAccessLog(AccessLogModel log) async {
    try {
      Logger().i('📝 Inserting access log: ${log.action}');

      final db = await database;
      final result = await db!.insert('access_logs', log.toMap());

      Logger().i('✅ Access log inserted');
      return result;
    } catch (e) {
      Logger().e('❌ Error inserting access log: $e');
      return 0;
    }
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
    try {
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

      final maps = await db!.query(
        'access_logs',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      Logger().i('📋 Found ${maps.length} access log(s)');
      return maps.map((map) => AccessLogModel.fromMap(map)).toList();
    } catch (e) {
      Logger().e('❌ Error getting access logs: $e');
      return [];
    }
  }

  /// Returns a map containing the total number of access logs, the number of granted access logs, and the number of denied access logs.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<Map<String, dynamic>> getAccessStats() async {
    try {
      final db = await database;

      final total = await db!.rawQuery(
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
    } catch (e) {
      Logger().e('❌ Error getting access stats: $e');
      return {'total': 0, 'granted': 0, 'denied': 0};
    }
  }

  /// Clears old access logs from the database, keeping logs from the last [daysToKeep] days.
  ///
  /// Throws a [SqliteException] if the query fails.
  ///
  /// Returns the number of deleted rows.
  Future<int> clearOldLogs(int daysToKeep) async {
    try {
      final db = await database;
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      final result = await db!.delete(
        'access_logs',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );

      Logger().i('🗑️ Cleared $result old log(s)');
      return result;
    } catch (e) {
      Logger().e('❌ Error clearing old logs: $e');
      return 0;
    }
  }

  /// Closes the database connection.
  ///
  /// You should call this method when you are done using the database service.
  ///
  /// Throws a [SqliteException] if the query fails.
  Future<void> close() async {
    final db = await database;
    db!.close();
  }

  Future<void> debugPrintAllUsers() async {
    try {
      final db = await database;
      final maps = await db!.query('users');

      Logger().i('=' * 50);
      Logger().i('DEBUG: All Users in Database');
      Logger().i('=' * 50);

      if (maps.isEmpty) {
        Logger().i('No users found');
      } else {
        for (var i = 0; i < maps.length; i++) {
          Logger().i('User ${i + 1}:');
          Logger().i('  ID: ${maps[i]['id']}');
          Logger().i('  Name: ${maps[i]['name']}');
          Logger().i('  Employee ID: ${maps[i]['employee_id']}');
          Logger().i('  Department: ${maps[i]['department']}');
          Logger().i('  Created: ${maps[i]['created_at']}');
          Logger().i('  Active: ${maps[i]['is_active']}');
          Logger().i('---');
        }
      }
      Logger().i('=' * 50);
    } catch (e) {
      Logger().i('❌ Error in debug print: $e');
    }
  }

  Future<void> resetDatabase() async {
    try {
      Logger().i('🔄 Resetting database...');

      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'face_recognition.db');

      await deleteDatabase(path);
      _database = null;

      Logger().i('✅ Database reset complete');

      // Reinitialize
      await database;
    } catch (e) {
      Logger().e('❌ Error resetting database: $e');
    }
  }
}

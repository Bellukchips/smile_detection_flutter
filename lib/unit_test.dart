// ==================== 1. Test Database Schema ====================
// Tambahkan ini di main.dart sebelum runApp()

import 'package:face_detection_local/database_service.dart';
import 'package:face_detection_local/models/user.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

Future<void> testDatabaseSchema() async {
  try {
    Logger().i('\n' + '='*60);
    Logger().i('DATABASE SCHEMA TEST');
    Logger().i('='*60);
    
    final db = await DatabaseService.instance.database;
    
    // Check if users table exists
    final tables = await db!.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
    );
    
    if (tables.isEmpty) {
      Logger().i('❌ Users table does NOT exist!');
      return;
    }
    Logger().i('✅ Users table exists');
    
    // Get column info
    final columns = await db.rawQuery('PRAGMA table_info(users)');
    
    Logger().i('\nUsers table columns:');
    for (var col in columns) {
      Logger().i('  ${col['cid']}: ${col['name']} (${col['type']}) '
            'NOT NULL: ${col['notnull']} '
            'DEFAULT: ${col['dflt_value']}');
    }
    
    Logger().i('\n' + '='*60 + '\n');
    
  } catch (e, stack) {
    Logger().i('❌ Schema test error: $e');
    Logger().i(stack);
  }
}

// ==================== 2. Test Manual Insert ====================

Future<void> testManualInsert() async {
  try {
    Logger().i('\n' + '='*60);
    Logger().i('MANUAL INSERT TEST');
    Logger().i('='*60);
    
    final db = await DatabaseService.instance.database;
    
    // Create test data with EXACT column names
    final testData = {
      'id': 'test-${DateTime.now().millisecondsSinceEpoch}',
      'name': 'Test User',
      'employee_id': 'TEST001', // ← Note: snake_case
      'department': 'IT',        // ← Note: correct spelling
      'face_embedding': List.generate(128, (i) => i * 0.01).join(','),
      'photo_path': '/test/path.jpg',
      'created_at': DateTime.now().toIso8601String(),
      'is_active': 1,
    };
    
    Logger().i('Test data:');
    testData.forEach((key, value) {
      final valueStr = value.toString();
      final display = valueStr.length > 50 
          ? '${valueStr.substring(0, 50)}...' 
          : valueStr;
      Logger().i('  $key: $display');
    });
    
    Logger().i('\nInserting...');
    final result = await db!.insert('users', testData);
    Logger().i('✅ Insert successful! Row ID: $result');
    
    // Query back
    Logger().i('\nQuerying back...');
    final query = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [testData['id']],
    );
    
    if (query.isNotEmpty) {
      Logger().i('✅ Query successful!');
      Logger().i('Retrieved: ${query.first['name']}');
    }
    
    // Clean up
    await db.delete('users', where: 'id = ?', whereArgs: [testData['id']]);
    Logger().i('✅ Cleanup successful');
    
    Logger().i('='*60 + '\n');
    
  } catch (e, stack) {
    Logger().i('❌ Manual insert error: $e');
    Logger().i(stack);
  }
}

// ==================== 3. Test UserModel.toMap() ====================

void testUserModelToMap() {
  try {
    Logger().i('\n' + '='*60);
    Logger().i('USERMODEL.TOMAP() TEST');
    Logger().i('='*60);
    
    final testEmbedding = List.generate(128, (i) => i * 0.01);
    
    final user = UserModel(
      id: 'test-123',
      name: 'Test User',
      employeeId: 'EMP001',
      department: 'IT',
      faceEmbedding: testEmbedding,
      photoPath: '/test/photo.jpg',
      createdAt: DateTime.now(),
      isActive: true,
    );
    
    Logger().i('UserModel created');
    Logger().i('  Name: ${user.name}');
    Logger().i('  Employee ID: ${user.employeeId}');
    Logger().i('  Department: ${user.department}');
    Logger().i('  Embedding length: ${user.faceEmbedding.length}');
    
    Logger().i('\nCalling toMap()...');
    final map = user.toMap();
    
    Logger().i('\nMap keys and values:');
    map.forEach((key, value) {
      final valueStr = value.toString();
      final display = valueStr.length > 50 
          ? '${valueStr.substring(0, 50)}...' 
          : valueStr;
      Logger().i('  "$key": $display');
    });
    
    // Check for common mistakes
    Logger().i('\nValidation:');
    
    final expectedKeys = [
      'id', 'name', 'employee_id', 'department', 
      'face_embedding', 'photo_path', 'created_at', 'is_active'
    ];
    
    for (var key in expectedKeys) {
      if (map.containsKey(key)) {
        Logger().i('  ✅ $key exists');
      } else {
        Logger().i('  ❌ $key MISSING!');
      }
    }
    
    // Check for wrong keys (camelCase instead of snake_case)
    final wrongKeys = [
      'employeeId', 'departement', 'faceEmbedding', 
      'photoPath', 'createdAt', 'isActive'
    ];
    
    for (var key in wrongKeys) {
      if (map.containsKey(key)) {
        Logger().i('  ❌ WRONG KEY FOUND: $key (should be snake_case!)');
      }
    }
    
    Logger().i('='*60 + '\n');
    
  } catch (e, stack) {
    Logger().i('❌ UserModel.toMap() error: $e');
    Logger().i(stack);
  }
}

// ==================== 4. Full Registration Simulation ====================

Future<void> simulateRegistration() async {
  try {
    Logger().i('\n${'='*60}');
    Logger().i('FULL REGISTRATION SIMULATION');
    Logger().i('='*60);
    
    // Simulate form data
    final name = 'John Doe';
    final employeeId = 'EMP${DateTime.now().millisecondsSinceEpoch}';
    final department = 'Engineering';
    
    Logger().i('Step 1: Form data');
    Logger().i('  Name: $name');
    Logger().i('  Employee ID: $employeeId');
    Logger().i('  Department: $department');
    
    // Simulate embedding (normally from ML)
    Logger().i('\nStep 2: Generate embedding (simulated)');
    final embedding = List.generate(128, (i) => (i * 0.01));
    Logger().i('  ✅ Embedding generated: ${embedding.length} dimensions');
    
    // Create photo path (simulated)
    Logger().i('\nStep 3: Photo path (simulated)');
    final photoPath = '/data/user/0/com.example.app/files/test.jpg';
    Logger().i('  ✅ Photo path: $photoPath');
    
    // Create UserModel
    Logger().i('\nStep 4: Create UserModel');
    final user = UserModel(
      id: const Uuid().v4(),
      name: name,
      employeeId: employeeId,
      department: department,
      faceEmbedding: embedding,
      photoPath: photoPath,
      createdAt: DateTime.now(),
      isActive: true,
    );
    Logger().i('  ✅ UserModel created');
    
    // Convert to map
    Logger().i('\nStep 5: Convert to map');
    final userMap = user.toMap();
    Logger().i('  ✅ Map created with ${userMap.length} keys');
    
    // Insert to database
    Logger().i('\nStep 6: Insert to database');
    final result = await DatabaseService.instance.insertUser(user);
    Logger().i('  ✅ Insert successful! Result: $result');
    
    // Verify
    Logger().i('\nStep 7: Verify insertion');
    final retrieved = await DatabaseService.instance.getUserByEmployeeId(employeeId);
    if (retrieved != null) {
      Logger().i('  ✅ User retrieved: ${retrieved.name}');
    } else {
      Logger().i('  ❌ Failed to retrieve user!');
    }
    
    // Cleanup
    Logger().i('\nStep 8: Cleanup');
    await DatabaseService.instance.deleteUser(user.id);
    Logger().i('  ✅ Cleanup successful');
    
    Logger().i('\n' + '='*60);
    Logger().i('✅ ALL TESTS PASSED!');
    Logger().i('='*60 + '\n');
    
  } catch (e, stack) {
    Logger().i('\n' + '='*60);
    Logger().i('❌ SIMULATION FAILED!');
    Logger().i('='*60);
    Logger().i('Error: $e');
    Logger().i('\nStack trace:');
    Logger().i(stack);
    Logger().i('='*60 + '\n');
  }
}

// ==================== 5. Run All Tests ====================

Future<void> runAllDatabaseTests() async {
  Logger().i('\n\n');
  Logger().i('╔════════════════════════════════════════════════════════════╗');
  Logger().i('║         FACE RECOGNITION DATABASE DEBUG TESTS             ║');
  Logger().i('╚════════════════════════════════════════════════════════════╝');
  Logger().i('\n');
  
  await testDatabaseSchema();
  await Future.delayed(Duration(seconds: 1));
  
  await testManualInsert();
  await Future.delayed(Duration(seconds: 1));
  
  testUserModelToMap();
  await Future.delayed(Duration(seconds: 1));
  
  await simulateRegistration();
  
  Logger().i('\n');
  Logger().i('╔════════════════════════════════════════════════════════════╗');
  Logger().i('║                    TESTS COMPLETE                          ║');
  Logger().i('╚════════════════════════════════════════════════════════════╝');
  Logger().i('\n\n');
}
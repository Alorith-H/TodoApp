import 'dart:io' show Platform, Directory;

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import '../models/task.dart';
import '../models/category.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static sql.Database? _database;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  Future<sql.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<sql.Database> _initDatabase() async {
    String dbPath;

    if (_isMobile) {
      // Android/iOS: use native sqflite's getDatabasesPath
      dbPath = join(await sql.getDatabasesPath(), 'todo_app.db');
    } else {
      // Desktop: use FFI
      ffi.sqfliteFfiInit();
      sql.databaseFactory = ffi.databaseFactoryFfi;

      final appDocDir = await getApplicationDocumentsDirectory();
      final appDir = join(appDocDir.path, 'todo_app');
      final dir = Directory(appDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      dbPath = join(appDir, 'todo_app.db');
    }

    return await sql.openDatabase(
      dbPath,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(sql.Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        category_id INTEGER DEFAULT 1,
        due_date TEXT,
        is_completed INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        is_recurring INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color TEXT NOT NULL
      )
    ''');

    final batch = db.batch();
    for (final cat in Category.defaults()) {
      final map = cat.toMap();
      map.remove('id');
      batch.insert('categories', map);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(sql.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN is_recurring INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE categories DROP COLUMN icon');
    }
  }

  // ═══════════════════════════════
  //  Category CRUD
  // ═══════════════════════════════

  Future<int> addCategory(Category category) async {
    final db = await database;
    return await db.insert('categories', {
      'name': category.name,
      'color': category.color,
    });
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    await db.update(
      'tasks',
      {'category_id': 1},
      where: 'category_id = ?',
      whereArgs: [id],
    );
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════
  //  Task CRUD
  // ═══════════════════════════════

  Future<List<Task>> getAllTasks({
    int? categoryId,
    String? searchQuery,
    String sortBy = 'due_date',
    bool includeCompleted = true,
  }) async {
    final db = await database;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (categoryId != null && categoryId > 0) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }

    if (!includeCompleted) {
      conditions.add('is_completed = 0');
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('title LIKE ?');
      args.add('%$searchQuery%');
    }

    final where = conditions.isNotEmpty ? conditions.join(' AND ') : null;
    final whereArgs = args.isNotEmpty ? args : null;

    String orderBy;
    if (sortBy == 'created_at') {
      orderBy = 'is_completed ASC, created_at DESC';
    } else {
      orderBy = 'is_completed ASC, due_date ASC NULLS LAST, created_at DESC';
    }

    final maps = await db.query(
      'tasks',
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );

    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> addTask(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap());
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ═══════════════════════════════
  //  Recurring tasks
  // ═══════════════════════════════

  Future<List<Task>> getRecurringTasks() async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'is_recurring = 1',
    );
    return maps.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> duplicateRecurringTask(Task task) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final newTask = Task(
      title: task.title,
      description: task.description,
      categoryId: task.categoryId,
      dueDate: todayDate,
      isRecurring: true,
    );
    return await addTask(newTask);
  }

  Future<void> checkAndGenerateRecurringTasks() async {
    final db = await database;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final todayStr = todayDate.toIso8601String().substring(0, 10);

    final templates = await db.query('tasks', where: 'is_recurring = 1');

    for (final map in templates) {
      final template = Task.fromMap(map);

      final existing = await db.query(
        'tasks',
        where: 'title = ? AND substr(due_date, 1, 10) = ? AND is_recurring = 1',
        whereArgs: [template.title, todayStr],
      );

      if (existing.isEmpty) {
        await db.insert('tasks', {
          'title': template.title,
          'description': template.description,
          'category_id': template.categoryId,
          'due_date': todayDate.toIso8601String(),
          'is_completed': 0,
          'created_at': DateTime.now().toIso8601String(),
          'is_recurring': 1,
        });
      }
    }
  }

  Future<Map<String, int>> getTaskStats() async {
    final db = await database;
    final totalResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM tasks');
    final completedResult =
        await db.rawQuery('SELECT COUNT(*) as cnt FROM tasks WHERE is_completed = 1');
    final total = totalResult.first['cnt'] as int;
    final completed = completedResult.first['cnt'] as int;
    return {
      'total': total,
      'completed': completed,
      'pending': total - completed,
    };
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories');
    final categories = maps.map((map) => Category.fromMap(map)).toList();

    for (int i = 0; i < categories.length; i++) {
      final countResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM tasks WHERE category_id = ?',
        [categories[i].id],
      );
      final count = countResult.isNotEmpty ? countResult.first['cnt'] as int? : 0;
      categories[i] = categories[i].copyWith(taskCount: count ?? 0);
    }

    return categories;
  }
}

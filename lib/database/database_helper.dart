import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'attendance.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Employees table
    await db.execute('''
      CREATE TABLE employees(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        employee_id TEXT NOT NULL UNIQUE,
        face_encoding TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Attendance table
    await db.execute('''
      CREATE TABLE attendance(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT NOT NULL,
        check_in TEXT NOT NULL,
        check_out TEXT,
        date TEXT NOT NULL,
        FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
      )
    ''');
  }

  // Insert employee
  Future<int> insertEmployee(Map<String, dynamic> employee) async {
    Database db = await database;
    return await db.insert('employees', employee);
  }

  // Get all employees
  Future<List<Map<String, dynamic>>> getEmployees() async {
    Database db = await database;
    return await db.query('employees');
  }

  // Get employee by ID
  Future<Map<String, dynamic>?> getEmployeeById(String employeeId) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'employees',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Insert attendance
  Future<int> insertAttendance(Map<String, dynamic> attendance) async {
    Database db = await database;
    return await db.insert('attendance', attendance);
  }

  // Update check-out time
  Future<int> updateCheckOut(int id, String checkOut) async {
    Database db = await database;
    return await db.update(
      'attendance',
      {'check_out': checkOut},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get attendance by date
  Future<List<Map<String, dynamic>>> getAttendanceByDate(String date) async {
    Database db = await database;
    return await db.query(
      'attendance',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  // Get today's attendance for an employee
  Future<Map<String, dynamic>?> getTodayAttendance(String employeeId, String date) async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'attendance',
      where: 'employee_id = ? AND date = ?',
      whereArgs: [employeeId, date],
      orderBy: 'check_in DESC',
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // Delete employee
  Future<int> deleteEmployee(String employeeId) async {
    Database db = await database;
    return await db.delete(
      'employees',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
    );
  }
}
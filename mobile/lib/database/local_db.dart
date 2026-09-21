import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDb {
  static Database? _db;

  static Future<Database> get db async {
    if(_db!=null)return _db!;
    final p=join(await getDatabasesPath(),'uni_attend.db');
    _db=await openDatabase(p,version:1,onCreate:(db,v)async{
      await db.execute('CREATE TABLE queue(id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT UNIQUE, payload TEXT, created_at TEXT, synced INTEGER DEFAULT 0)');
      await db.execute('CREATE TABLE attendance(id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT UNIQUE, payload TEXT, created_at TEXT)');
    });
    return _db!;
  }

  static Future<void> saveAttendance(String key,Map<String,dynamic> payload)async{
    final d=await db;
    await d.insert('attendance',{'key':key,'payload':jsonEncode(payload),'created_at':DateTime.now().toIso8601String()},conflictAlgorithm:ConflictAlgorithm.ignore);
  }

  static Future<void> queue(String key,Map<String,dynamic> payload)async{
    final d=await db;
    await d.insert('queue',{'key':key,'payload':jsonEncode(payload),'created_at':DateTime.now().toIso8601String()},conflictAlgorithm:ConflictAlgorithm.ignore);
  }

  static Future<List<Map<String,Object?>>> pending()async{
    final d=await db;
    return d.query('queue',where:'synced=0',orderBy:'id');
  }

  static Future<void> synced(int id)async{
    final d=await db;
    await d.update('queue',{'synced':1},where:'id=?',whereArgs:[id]);
  }
}

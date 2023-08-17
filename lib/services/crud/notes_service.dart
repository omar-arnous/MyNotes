import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;
import "package:path_provider/path_provider.dart";

import 'crud_exceptions.dart';

class NotesService {
  Database? _db;

  List<DatabaseNote> _notes = [];

  static final NotesService _shared = NotesService._sharedInstance();
  NotesService._sharedInstance();
  factory NotesService() => _shared;

  final _notesStreamController =
      StreamController<List<DatabaseNote>>.broadcast();

  Stream<List<DatabaseNote>> get allNotes => _notesStreamController.stream;

  Future<DatabaseUser> getOrCreateUser({required String email}) async {
    try {
      final user = await getUser(email: email);
      return user;
    } on CouldNotFindUser {
      final createdUser = await createUser(email: email);
      return createdUser;
    } catch (err) {
      rethrow;
    }
  }

  Future<void> _cahceNotes() async {
    final allNotes = await getAllNotes();
    _notes = allNotes.toList();
    _notesStreamController.add(_notes);
  }

  Future<DatabaseNote> updateNote(
      {required DatabaseNote note, required String text}) async {
    await _ensureDbIsOpen();
    final db = _getDatabase();

    // make sure note exists
    await getNote(id: note.id);

    // update DB
    final updatesCount = await db.update(noteTable, {
      textColumn: text,
      isSynchedWithCloudColumn: 0,
    });

    if (updatesCount == 0) {
      throw CouldNotUpdateNote();
    }

    final updatedNote = await getNote(id: note.id);
    _notes.removeWhere((note) => note.id == updatedNote.id);
    _notes.add(updatedNote);
    _notesStreamController.add(_notes);

    return updatedNote;
  }

  Future<Iterable<DatabaseNote>> getAllNotes() async {
    await _ensureDbIsOpen();
    final db = _getDatabase();
    final notes = await db.query(noteTable);

    return notes.map((note) => DatabaseNote.fromRow(note));
  }

  Future<DatabaseNote> getNote({required int id}) async {
    await _ensureDbIsOpen();
    final db = _getDatabase();
    final notes = await db.query(
      noteTable,
      limit: 1,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (notes.isEmpty) {
      throw CouldNotDeleteNote();
    }

    final note = DatabaseNote.fromRow(notes.first);
    _notes.removeWhere((note) => note.id == id);
    _notes.add(note);
    _notesStreamController.add(_notes);

    return note;
  }

  Future<int> deleteAllNotes() async {
    await _ensureDbIsOpen();
    final db = _getDatabase();
    final numberOfDeletions = await db.delete(noteTable);

    _notes = [];
    _notesStreamController.add(_notes);

    return numberOfDeletions;
  }

  Future<void> deleteNote({required int id}) async {
    await _ensureDbIsOpen();
    final db = _getDatabase();
    final deletedCount = await db.delete(
      noteTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (deletedCount == 0) {
      throw CouldNotDeleteNote();
    }

    _notes.removeWhere((note) => note.id == id);
    _notesStreamController.add(_notes);
  }

  Future<DatabaseNote> createNote({required DatabaseUser owner}) async {
    await _ensureDbIsOpen();
    final db = _getDatabase();

    final dbUser = await getUser(email: owner.email);
    if (dbUser != owner) {
      throw CouldNotFindUser();
    }

    // create the note
    const text = '';
    final noteId = await db.insert(noteTable, {
      userIdColumn: owner.id,
      textColumn: text,
      isSynchedWithCloudColumn: 1,
    });

    final note = DatabaseNote(
      id: noteId,
      userId: owner.id,
      text: text,
      isSynchedWithCloud: true,
    );

    _notes.add(note);
    _notesStreamController.add(_notes);

    return note;
  }

  Future<DatabaseUser> getUser({required String email}) async {
    await _ensureDbIsOpen();
    final db = _getDatabase();

    final results = await db.query(
      userTable,
      limit: 1,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );

    if (results.isEmpty) {
      throw CouldNotFindUser();
    }

    return DatabaseUser.fromRow(results.first);
  }

  Future<DatabaseUser> createUser({required String email}) async {
    await _ensureDbIsOpen();
    final db = _getDatabase();
    final results = await db.query(
      userTable,
      limit: 1,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );

    if (results.isNotEmpty) {
      throw UserAlreadyExists();
    }

    final userId =
        await db.insert(userTable, {emailColumn: email.toLowerCase()});
    return DatabaseUser(id: userId, email: email);
  }

  Future<void> deleteUser({required String email}) async {
    await _ensureDbIsOpen();
    final db = _getDatabase();
    final deletedCount = await db.delete(
      userTable,
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (deletedCount != 1) {
      throw CouldNotDeleteUser();
    }
  }

  Database _getDatabase() {
    final db = _db;
    if (db == null) {
      throw DatabaseIsNotOpen();
    }

    return db;
  }

  Future<void> open() async {
    if (_db != null) {
      throw DatabaseAlreadyOpenException();
    }

    try {
      final docsPath = await getApplicationDocumentsDirectory();
      final dbPath = join(docsPath.path, dbName);
      final db = await openDatabase(dbPath);
      _db = db;

      //  create user table
      await db.execute(createUserTable);

      // create note table
      await db.execute(createNoteTable);
      await _cahceNotes();
    } on MissingPlatformDirectoryException {
      throw UnableToGetDocumentsDirectory();
    }
  }

  Future<void> _ensureDbIsOpen() async {
    try {
      await open();
    } on DatabaseAlreadyOpenException {
      // code
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db == null) throw DatabaseIsNotOpen();

    await db.close();
    _db = null;
  }
}

@immutable
class DatabaseUser {
  final int id;
  final String email;

  const DatabaseUser({required this.id, required this.email});

  DatabaseUser.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        email = map[emailColumn] as String;

  @override
  String toString() => 'Person, ID= $id, Email= $email';

  @override
  bool operator ==(covariant DatabaseUser other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

@immutable
class DatabaseNote {
  final int id;
  final int userId;
  final String text;
  final bool isSynchedWithCloud;

  const DatabaseNote({
    required this.id,
    required this.userId,
    required this.text,
    required this.isSynchedWithCloud,
  });

  DatabaseNote.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        userId = map[userIdColumn] as int,
        text = map[textColumn] as String,
        isSynchedWithCloud =
            (map[isSynchedWithCloudColumn] as int) == 1 ? true : false;

  @override
  String toString() =>
      'Note, ID = $id, userId = $userId, isSynchedWithCloud = $isSynchedWithCloud';

  @override
  bool operator ==(covariant DatabaseNote other) => id == other.id;

  @override
  int get hashCode => id.hashCode;
}

const dbName = 'notes.db';
const noteTable = 'note';
const userTable = 'user';
const idColumn = 'id';
const emailColumn = 'email';
const userIdColumn = 'user_id';
const textColumn = 'text';
const isSynchedWithCloudColumn = 'is_synched_with_cloud';

const createUserTable = ''' CREATE TABLE IF NOT EXISTS "user" (
	      "id"	INTEGER NOT NULL,
	      "email"	TEXT NOT NULL UNIQUE,
	      PRIMARY KEY("id" AUTOINCREMENT)
        );''';

const createNoteTable = '''CREATE TABLE IF NOT EXISTS "note" (
	      "id"	INTEGER NOT NULL,
	      "user_id"	INTEGER NOT NULL,
	      "text"	TEXT NOT NULL,
	      "is_synched_with_cloud"	INTEGER NOT NULL DEFAULT 0,
  	    FOREIGN KEY("user_id") REFERENCES "user"("id"),
	      PRIMARY KEY("id" AUTOINCREMENT)
        );''';

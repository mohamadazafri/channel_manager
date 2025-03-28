import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/booking.dart';
import '../../models/room.dart';
import '../../models/enums/booking_source.dart';

/// Service for managing local database operations for bookings and rooms.
class LocalDatabaseService {
  static const String databaseName = 'homestay_booking.db';
  static const int databaseVersion = 1;
  
  // Table names
  static const String bookingTable = 'bookings';
  static const String roomTable = 'rooms';
  
  Database? _database;
  
  // Singleton pattern
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  
  factory LocalDatabaseService() => _instance;
  
  LocalDatabaseService._internal();
  
  /// Gets the database instance, initializing it if necessary.
  Future<Database> get database async {
    if (_database != null) return _database!;
    
    _database = await _initDatabase();
    return _database!;
  }
  
  /// Initializes the database.
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, databaseName);
    
    return await openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  /// Creates database tables.
  Future<void> _onCreate(Database db, int version) async {
    // Create bookings table
    await db.execute('''
      CREATE TABLE $bookingTable (
        id TEXT PRIMARY KEY,
        guest_name TEXT NOT NULL,
        check_in TEXT NOT NULL,
        check_out TEXT NOT NULL,
        source TEXT NOT NULL,
        room_id TEXT NOT NULL,
        is_confirmed INTEGER NOT NULL DEFAULT 1,
        notes TEXT,
        guest_email TEXT,
        guest_phone TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Create rooms table
    await db.execute('''
      CREATE TABLE $roomTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        capacity INTEGER NOT NULL,
        price REAL NOT NULL,
        is_available INTEGER NOT NULL DEFAULT 1,
        description TEXT,
        image_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }
  
  /// Handles database upgrades.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema migrations here
  }
  
  /// Inserts a new booking into the database.
  Future<String> insertBooking(Booking booking) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    final data = {
      'id': booking.id,
      'guest_name': booking.guestName,
      'check_in': booking.checkIn.toIso8601String(),
      'check_out': booking.checkOut.toIso8601String(),
      'source': booking.source.toShortString(),
      'room_id': booking.roomId,
      'is_confirmed': booking.isConfirmed ? 1 : 0,
      'notes': booking.notes,
      'guest_email': booking.guestEmail,
      'guest_phone': booking.guestPhone,
      'created_at': now,
      'updated_at': now,
    };
    
    await db.insert(
      bookingTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    return booking.id;
  }
  
  /// Updates an existing booking in the database.
  Future<int> updateBooking(Booking booking) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    final data = {
      'guest_name': booking.guestName,
      'check_in': booking.checkIn.toIso8601String(),
      'check_out': booking.checkOut.toIso8601String(),
      'source': booking.source.toShortString(),
      'room_id': booking.roomId,
      'is_confirmed': booking.isConfirmed ? 1 : 0,
      'notes': booking.notes,
      'guest_email': booking.guestEmail,
      'guest_phone': booking.guestPhone,
      'updated_at': now,
    };
    
    return await db.update(
      bookingTable,
      data,
      where: 'id = ?',
      whereArgs: [booking.id],
    );
  }
  
  /// Deletes a booking from the database.
  Future<int> deleteBooking(String id) async {
    final db = await database;
    
    return await db.delete(
      bookingTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// Gets a booking by its ID.
  Future<Booking?> getBookingById(String id) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      bookingTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    
    return _mapToBooking(maps.first);
  }
  
  /// Gets all bookings within a date range.
  Future<List<Booking>> getBookings({DateTime? from, DateTime? to}) async {
    final db = await database;
    
    String? whereClause;
    List<dynamic>? whereArgs;
    
    if (from != null && to != null) {
      // Find bookings that overlap with the date range
      whereClause = '(check_in <= ? AND check_out >= ?)';
      whereArgs = [to.toIso8601String(), from.toIso8601String()];
    } else if (from != null) {
      whereClause = 'check_out >= ?';
      whereArgs = [from.toIso8601String()];
    } else if (to != null) {
      whereClause = 'check_in <= ?';
      whereArgs = [to.toIso8601String()];
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      bookingTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'check_in ASC',
    );
    
    return List.generate(maps.length, (i) => _mapToBooking(maps[i]));
  }
  
  /// Gets bookings for a specific room.
  Future<List<Booking>> getBookingsByRoom(String roomId, {DateTime? from, DateTime? to}) async {
    final db = await database;
    
    String whereClause = 'room_id = ?';
    List<dynamic> whereArgs = [roomId];
    
    if (from != null && to != null) {
      whereClause += ' AND (check_in <= ? AND check_out >= ?)';
      whereArgs.addAll([to.toIso8601String(), from.toIso8601String()]);
    } else if (from != null) {
      whereClause += ' AND check_out >= ?';
      whereArgs.add(from.toIso8601String());
    } else if (to != null) {
      whereClause += ' AND check_in <= ?';
      whereArgs.add(to.toIso8601String());
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      bookingTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'check_in ASC',
    );
    
    return List.generate(maps.length, (i) => _mapToBooking(maps[i]));
  }
  
  /// Adds a new room to the database.
  Future<String> insertRoom(Room room) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    final data = {
      'id': room.id,
      'name': room.name,
      'type': room.type,
      'capacity': room.capacity,
      'price': room.price,
      'is_available': room.isAvailable ? 1 : 0,
      'description': room.description,
      'image_url': room.imageUrl,
      'created_at': now,
      'updated_at': now,
    };
    
    await db.insert(
      roomTable,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    return room.id;
  }
  
  /// Updates an existing room in the database.
  Future<int> updateRoom(Room room) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    final data = {
      'name': room.name,
      'type': room.type,
      'capacity': room.capacity,
      'price': room.price,
      'is_available': room.isAvailable ? 1 : 0,
      'description': room.description,
      'image_url': room.imageUrl,
      'updated_at': now,
    };
    
    return await db.update(
      roomTable,
      data,
      where: 'id = ?',
      whereArgs: [room.id],
    );
  }
  
  /// Deletes a room from the database.
  Future<int> deleteRoom(String id) async {
    final db = await database;
    
    return await db.delete(
      roomTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  /// Gets a room by its ID.
  Future<Room?> getRoomById(String id) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      roomTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    
    return _mapToRoom(maps.first);
  }
  
  /// Gets all rooms.
  Future<List<Room>> getAllRooms({bool availableOnly = false}) async {
    final db = await database;
    
    String? whereClause;
    List<dynamic>? whereArgs;
    
    if (availableOnly) {
      whereClause = 'is_available = ?';
      whereArgs = [1];
    }
    
    final List<Map<String, dynamic>> maps = await db.query(
      roomTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    
    return List.generate(maps.length, (i) => _mapToRoom(maps[i]));
  }
  
  /// Converts a database map to a Booking object.
  Booking _mapToBooking(Map<String, dynamic> map) {
    return Booking(
      id: map['id'],
      guestName: map['guest_name'],
      checkIn: DateTime.parse(map['check_in']),
      checkOut: DateTime.parse(map['check_out']),
      source: BookingSourceExtension.fromString(map['source']),
      roomId: map['room_id'],
      isConfirmed: map['is_confirmed'] == 1,
      notes: map['notes'],
      guestEmail: map['guest_email'],
      guestPhone: map['guest_phone'],
    );
  }
  
  /// Converts a database map to a Room object.
  Room _mapToRoom(Map<String, dynamic> map) {
    return Room(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      capacity: map['capacity'],
      price: map['price'],
      isAvailable: map['is_available'] == 1,
      description: map['description'],
      imageUrl: map['image_url'],
    );
  }
  
  /// Checks if a room has any overlapping bookings in a date range.
  Future<bool> hasOverlappingBookings(String roomId, DateTime checkIn, DateTime checkOut, {String? excludeBookingId}) async {
    final db = await database;
    
    String whereClause = '''
      room_id = ? AND 
      ((check_in <= ? AND check_out > ?) OR 
      (check_in < ? AND check_out >= ?) OR 
      (check_in >= ? AND check_out <= ?))
    ''';
    
    List<dynamic> whereArgs = [
      roomId,
      checkOut.toIso8601String(), checkIn.toIso8601String(),
      checkOut.toIso8601String(), checkIn.toIso8601String(),
      checkIn.toIso8601String(), checkOut.toIso8601String(),
    ];
    
    if (excludeBookingId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeBookingId);
    }
    
    final List<Map<String, dynamic>> result = await db.query(
      bookingTable,
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );
    
    return result.isNotEmpty;
  }
}

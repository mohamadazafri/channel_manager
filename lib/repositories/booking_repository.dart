import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/booking.dart';
import '../models/enums/booking_source.dart';
import '../services/api/booking_api_service.dart';
import '../services/api/booking_dot_com_service.dart';
import '../services/api/agoda_service.dart';
import '../services/api/airbnb_service.dart';
import '../services/local/local_database_service.dart';

/// Repository that coordinates booking data from local database and external APIs.
class BookingRepository {
  final BookingDotComService _bookingDotComService;
  final AgodaService _agodaService;
  final AirbnbService _airbnbService;
  final LocalDatabaseService _dbService;
  
  final _uuid = const Uuid();
  
  // Stream controller for broadcasting booking changes
  final _bookingStreamController = StreamController<List<Booking>>.broadcast();
  
  /// Creates a new BookingRepository with the provided services.
  BookingRepository(
    this._bookingDotComService,
    this._agodaService,
    this._airbnbService,
    this._dbService,
  );
  
  /// Stream of booking changes.
  Stream<List<Booking>> get bookingsStream => _bookingStreamController.stream;
  
  /// Fetches bookings from all sources.
  Future<List<Booking>> fetchAllBookings({DateTime? from, DateTime? to}) async {
    List<Booking> allBookings = [];
    List<Future<List<Booking>>> futures = [];
    
    // Add manual bookings from local database
    futures.add(_dbService.getBookings(from: from, to: to));
    
    // Fetch from Booking.com
    if (await _bookingDotComService.isConnected()) {
      try {
        futures.add(_bookingDotComService.fetchBookings(from: from, to: to));
      } catch (e) {
        print('Error fetching Booking.com bookings: $e');
      }
    }
    
    // Fetch from Agoda
    if (await _agodaService.isConnected()) {
      try {
        futures.add(_agodaService.fetchBookings(from: from, to: to));
      } catch (e) {
        print('Error fetching Agoda bookings: $e');
      }
    }
    
    // Fetch from Airbnb
    if (await _airbnbService.isConnected()) {
      try {
        futures.add(_airbnbService.fetchBookings(from: from, to: to));
      } catch (e) {
        print('Error fetching Airbnb bookings: $e');
      }
    }
    
    // Wait for all API calls to complete
    final results = await Future.wait(futures);
    
    // Combine all results
    for (var bookings in results) {
      allBookings.addAll(bookings);
    }

    // Update the stream with the new bookings
    _bookingStreamController.add(allBookings);
    
    return allBookings;
  }
  
  /// Finds overlapping bookings in a list.
  List<Booking> findOverlappingBookings(List<Booking> bookings) {
    List<Booking> overlapping = [];
    
    for (int i = 0; i < bookings.length; i++) {
      for (int j = i + 1; j < bookings.length; j++) {
        if (bookings[i].overlapsWith(bookings[j])) {
          if (!overlapping.contains(bookings[i])) {
            overlapping.add(bookings[i]);
          }
          if (!overlapping.contains(bookings[j])) {
            overlapping.add(bookings[j]);
          }
        }
      }
    }
    
    return overlapping;
  }
  
  /// Creates a new manual booking.
  Future<Booking> createManualBooking(Booking booking) async {
    // Generate a UUID if not provided
    final String id = booking.id.isEmpty ? _uuid.v4() : booking.id;
    
    // Create a new booking with the correct source and ID
    final newBooking = booking.copyWith(
      id: id,
      source: BookingSource.manual,
    );
    
    // Check for overlaps
    final hasOverlap = await _dbService.hasOverlappingBookings(
      newBooking.roomId,
      newBooking.checkIn,
      newBooking.checkOut,
    );
    
    if (hasOverlap) {
      throw Exception('This booking overlaps with an existing booking for the same room');
    }
    
    // Save to local database
    await _dbService.insertBooking(newBooking);
    
    // Update the stream
    fetchAllBookings();
    
    return newBooking;
  }
  
  /// Updates a booking.
  Future<Booking> updateBooking(Booking booking) async {
    // Check for overlaps (excluding this booking)
    if (booking.source == BookingSource.manual) {
      final hasOverlap = await _dbService.hasOverlappingBookings(
        booking.roomId,
        booking.checkIn,
        booking.checkOut,
        excludeBookingId: booking.id,
      );
      
      if (hasOverlap) {
        throw Exception('This booking overlaps with an existing booking for the same room');
      }
      
      // Update in local database
      await _dbService.updateBooking(booking);
    } else {
      // Update in external API
      switch (booking.source) {
        case BookingSource.bookingDotCom:
          await _bookingDotComService.updateBooking(booking);
          break;
        case BookingSource.agoda:
          await _agodaService.updateBooking(booking);
          break;
        case BookingSource.airbnb:
          await _airbnbService.updateBooking(booking);
          break;
        default:
          break;
      }
    }
    
    // Update the stream
    fetchAllBookings();
    
    return booking;
  }
  
  /// Cancels a booking.
  Future<bool> cancelBooking(Booking booking) async {
    bool success = false;
    
    if (booking.source == BookingSource.manual) {
      // Delete from local database
      final deleted = await _dbService.deleteBooking(booking.id);
      success = deleted > 0;
    } else {
      // Cancel in external API
      switch (booking.source) {
        case BookingSource.bookingDotCom:
          success = await _bookingDotComService.cancelBooking(booking.id);
          break;
        case BookingSource.agoda:
          success = await _agodaService.cancelBooking(booking.id);
          break;
        case BookingSource.airbnb:
          success = await _airbnbService.cancelBooking(booking.id);
          break;
        default:
          break;
      }
    }
    
    // Update the stream if successful
    if (success) {
      fetchAllBookings();
    }
    
    return success;
  }
  
  /// Gets bookings for a specific date.
  Future<List<Booking>> getBookingsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    
    final allBookings = await fetchAllBookings(from: startOfDay, to: endOfDay);
    
    return allBookings.where((booking) {
      return (booking.checkIn.isBefore(endOfDay) && booking.checkOut.isAfter(startOfDay));
    }).toList();
  }
  
  /// Syncs all bookings from external sources to the local database.
  Future<void> syncAllBookings() async {
    final allExternalBookings = <Booking>[];
    
    // Fetch from Booking.com
    if (await _bookingDotComService.isConnected()) {
      try {
        final bookings = await _bookingDotComService.fetchBookings();
        allExternalBookings.addAll(bookings);
      } catch (e) {
        print('Error syncing Booking.com bookings: $e');
      }
    }
    
    // Fetch from Agoda
    if (await _agodaService.isConnected()) {
      try {
        final bookings = await _agodaService.fetchBookings();
        allExternalBookings.addAll(bookings);
      } catch (e) {
        print('Error syncing Agoda bookings: $e');
      }
    }
    
    // Fetch from Airbnb
    if (await _airbnbService.isConnected()) {
      try {
        final bookings = await _airbnbService.fetchBookings();
        allExternalBookings.addAll(bookings);
      } catch (e) {
        print('Error syncing Airbnb bookings: $e');
      }
    }
    
    // Save all external bookings to the local database
    for (var booking in allExternalBookings) {
      try {
        final existingBooking = await _dbService.getBookingById(booking.id);
        if (existingBooking == null) {
          await _dbService.insertBooking(booking);
        } else {
          await _dbService.updateBooking(booking);
        }
      } catch (e) {
        print('Error saving booking ${booking.id}: $e');
      }
    }
    
    // Update the stream
    final updatedBookings = await _dbService.getBookings();
    _bookingStreamController.add(updatedBookings);
  }
  
  /// Dispose of resources.
  void dispose() {
    _bookingStreamController.close();
  }
}

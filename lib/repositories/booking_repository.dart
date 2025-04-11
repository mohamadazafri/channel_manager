import 'dart:async';
import 'package:homestay_booking/services/firebase/firebase_booking_service.dart';
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
  final LocalDatabaseService _localDbService;
  final FirebaseBookingService _firebaseDbService;

  final _uuid = const Uuid();

  // Stream controller for broadcasting booking changes
  final _bookingStreamController = StreamController<List<Booking>>.broadcast();

  /// Creates a new BookingRepository with the provided services.
  BookingRepository(this._bookingDotComService, this._agodaService, this._airbnbService, this._localDbService, this._firebaseDbService);

  /// Stream of booking changes.
  Stream<List<Booking>> get bookingsStream => _bookingStreamController.stream;

  /// Fetches bookings from all sources.
  Future<List<Booking>> fetchAllBookings({DateTime? from, DateTime? to}) async {
    try {
      // Try to get from Firebase first
      final bookings = await _firebaseDbService.fetchBookings(from: from, to: to);

      // Optional: Update local cache for offline use
      for (var booking in bookings) {
        await _localDbService.insertBooking(booking);
      }

      return bookings;
    } catch (e) {
      print('Firebase fetch failed, using local data: $e');
      // Fall back to local data if Firebase fails
      return await _localDbService.getBookings(from: from, to: to);
    }
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
    try {
      // Check for overlaps first
      final overlaps = await _firebaseDbService.checkForOverlaps(booking);
      if (overlaps.isNotEmpty) {
        throw Exception('This booking overlaps with existing bookings');
      }

      // Create in Firebase
      final newBooking = await _firebaseDbService.createBooking(booking);

      // Also save locally for offline access
      await _localDbService.insertBooking(newBooking);

      return newBooking;
    } catch (e) {
      print('Failed to create booking in Firebase: $e');
      throw e;
    }
  }

  /// Updates a booking.
  Future<Booking> updateBooking(Booking booking) async {
    try {
      // Update in Firebase
      final updatedBooking = await _firebaseDbService.updateBooking(booking);

      // Update locally for offline access
      await _localDbService.updateBooking(updatedBooking);

      return updatedBooking;
    } catch (e) {
      print('Failed to update booking in Firebase: $e');
      throw e;
    }
  }

  /// Cancels a booking.
  Future<bool> cancelBooking(Booking booking) async {
    try {
      // Delete from Firebase
      final success = await _firebaseDbService.deleteBooking(booking.id);

      if (success) {
        // Also delete locally
        await _localDbService.deleteBooking(booking.id);
      }

      return success;
    } catch (e) {
      print('Failed to cancel booking: $e');
      return false;
    }
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
        final existingBooking = await _localDbService.getBookingById(booking.id);
        if (existingBooking == null) {
          await _localDbService.insertBooking(booking);
        } else {
          await _localDbService.updateBooking(booking);
        }
      } catch (e) {
        print('Error saving booking ${booking.id}: $e');
      }
    }

    // Update the stream
    final updatedBookings = await _localDbService.getBookings();
    _bookingStreamController.add(updatedBookings);
  }

  /// Dispose of resources.
  void dispose() {
    _bookingStreamController.close();
  }
}

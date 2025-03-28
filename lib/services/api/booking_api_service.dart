import 'package:flutter/foundation.dart';
import '../../models/booking.dart';

/// Interface defining the contract for all booking API services.
/// This ensures all platform-specific implementations follow the same pattern.
abstract class BookingApiService {
  /// Fetches bookings from an external platform.
  /// 
  /// [from] Optional start date to filter bookings.
  /// [to] Optional end date to filter bookings.
  /// 
  /// Returns a list of [Booking] objects from the platform.
  Future<List<Booking>> fetchBookings({DateTime? from, DateTime? to});
  
  /// Creates a new booking on the external platform.
  /// 
  /// [booking] The booking details to create.
  /// 
  /// Returns the created [Booking] with any platform-specific IDs or metadata.
  /// Note: Some platforms may not support creating bookings via API.
  Future<Booking> createBooking(Booking booking);
  
  /// Updates an existing booking on the external platform.
  /// 
  /// [booking] The booking with updated details.
  /// 
  /// Returns the updated [Booking] with any platform-specific changes.
  Future<Booking> updateBooking(Booking booking);
  
  /// Cancels a booking on the external platform.
  /// 
  /// [bookingId] The ID of the booking to cancel.
  /// 
  /// Returns true if cancellation was successful, false otherwise.
  Future<bool> cancelBooking(String bookingId);
  
  /// Connects to the API service with credentials.
  /// 
  /// [credentials] Map containing the authentication details.
  /// 
  /// Returns true if connection was successful, false otherwise.
  Future<bool> connect(Map<String, String> credentials);
  
  /// Checks if the API service is currently connected.
  /// 
  /// Returns true if connected, false otherwise.
  Future<bool> isConnected();
}

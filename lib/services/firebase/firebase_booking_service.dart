import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/booking.dart';

class FirebaseBookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'bookings';

  // Fetch all bookings
  Future<List<Booking>> fetchBookings({DateTime? from, DateTime? to}) async {
    Query query = _firestore.collection(_collection);

    // Apply date filters if provided
    if (from != null) {
      query = query.where('check_out', isGreaterThanOrEqualTo: from.toIso8601String());
    }
    if (to != null) {
      query = query.where('check_in', isLessThanOrEqualTo: to.toIso8601String());
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();
  }

  // Create a new booking
  Future<Booking> createBooking(Booking booking) async {
    final docRef = _firestore.collection(_collection).doc(booking.id);
    await docRef.set(booking.toFirestore());
    return booking;
  }

  // Update an existing booking
  Future<Booking> updateBooking(Booking booking) async {
    final docRef = _firestore.collection(_collection).doc(booking.id);

    // Create an update map with the updated_at timestamp
    Map<String, dynamic> updateData = booking.toFirestore();
    updateData['updated_at'] = DateTime.now().toIso8601String();

    await docRef.update(updateData);
    return booking;
  }

  // Delete a booking
  Future<bool> deleteBooking(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
      return true;
    } catch (e) {
      print('Error deleting booking: $e');
      return false;
    }
  }

  // Check for booking overlaps
  Future<List<Booking>> checkForOverlaps(Booking booking) async {
    // Get all bookings for the same room
    QuerySnapshot snapshot = await _firestore.collection(_collection).where('room_id', isEqualTo: booking.roomId).get();

    List<Booking> roomBookings = snapshot.docs
        .map((doc) => Booking.fromFirestore(doc))
        .where((b) => b.id != booking.id) // Exclude the current booking if updating
        .toList();

    // Check for overlaps manually
    return roomBookings.where((existingBooking) {
      return booking.checkIn.isBefore(existingBooking.checkOut) && booking.checkOut.isAfter(existingBooking.checkIn);
    }).toList();
  }
}

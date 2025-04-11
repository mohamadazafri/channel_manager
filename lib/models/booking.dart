import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'enums/booking_source.dart';

class Booking {
  final String id;
  final String guestName;
  final DateTime checkIn;
  final DateTime checkOut;
  final BookingSource source;
  final String roomId;
  final bool isConfirmed;
  final String? notes;
  final String? guestEmail;
  final String? guestPhone;

  Booking({
    required this.id,
    required this.guestName,
    required this.checkIn,
    required this.checkOut,
    required this.source,
    required this.roomId,
    this.isConfirmed = true,
    this.notes,
    this.guestEmail,
    this.guestPhone,
  });

  // Factory constructor to create a Booking from JSON
  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'],
      guestName: json['guest_name'],
      checkIn: DateTime.parse(json['check_in']),
      checkOut: DateTime.parse(json['check_out']),
      source: BookingSourceExtension.fromString(json['source']),
      roomId: json['room_id'],
      isConfirmed: json['is_confirmed'] ?? true,
      notes: json['notes'],
      guestEmail: json['guest_email'],
      guestPhone: json['guest_phone'],
    );
  }

  // Convert Booking to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guest_name': guestName,
      'check_in': checkIn.toIso8601String(),
      'check_out': checkOut.toIso8601String(),
      'source': source.toShortString(),
      'room_id': roomId,
      'is_confirmed': isConfirmed,
      'notes': notes,
      'guest_email': guestEmail,
      'guest_phone': guestPhone,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'guest_name': guestName,
      'check_in': checkIn.toIso8601String(),
      'check_out': checkOut.toIso8601String(),
      'source': source.toShortString(),
      'room_id': roomId,
      'is_confirmed': isConfirmed,
      'notes': notes,
      'guest_email': guestEmail,
      'guest_phone': guestPhone,
      'created_at': DateTime.now().toIso8601String(), // Track when this was created in Firestore
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static Booking fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Booking(
      id: doc.id,
      guestName: data['guest_name'],
      checkIn: DateTime.parse(data['check_in']),
      checkOut: DateTime.parse(data['check_out']),
      source: BookingSourceExtension.fromString(data['source']),
      roomId: data['room_id'],
      isConfirmed: data['is_confirmed'] ?? true,
      notes: data['notes'],
      guestEmail: data['guest_email'],
      guestPhone: data['guest_phone'],
    );
  }

  // Check if this booking overlaps with another booking
  bool overlapsWith(Booking other) {
    if (roomId != other.roomId) return false;

    return (checkIn.isBefore(other.checkOut) && checkOut.isAfter(other.checkIn));
  }

  // Get duration in days
  int get durationInDays {
    return checkOut.difference(checkIn).inDays;
  }

  // Get formatted check-in date
  String get formattedCheckIn {
    return DateFormat('MMM dd, yyyy').format(checkIn);
  }

  // Get formatted check-out date
  String get formattedCheckOut {
    return DateFormat('MMM dd, yyyy').format(checkOut);
  }

  // Get formatted date range
  String get dateRange {
    return '${DateFormat('MMM dd').format(checkIn)} - ${DateFormat('MMM dd').format(checkOut)}';
  }

  // Create a copy of this booking with optional new parameters
  Booking copyWith({
    String? id,
    String? guestName,
    DateTime? checkIn,
    DateTime? checkOut,
    BookingSource? source,
    String? roomId,
    bool? isConfirmed,
    String? notes,
    String? guestEmail,
    String? guestPhone,
  }) {
    return Booking(
      id: id ?? this.id,
      guestName: guestName ?? this.guestName,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      source: source ?? this.source,
      roomId: roomId ?? this.roomId,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      notes: notes ?? this.notes,
      guestEmail: guestEmail ?? this.guestEmail,
      guestPhone: guestPhone ?? this.guestPhone,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Booking &&
        other.id == id &&
        other.guestName == guestName &&
        other.checkIn == checkIn &&
        other.checkOut == checkOut &&
        other.source == source &&
        other.roomId == roomId &&
        other.isConfirmed == isConfirmed &&
        other.notes == notes &&
        other.guestEmail == guestEmail &&
        other.guestPhone == guestPhone;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        guestName.hashCode ^
        checkIn.hashCode ^
        checkOut.hashCode ^
        source.hashCode ^
        roomId.hashCode ^
        isConfirmed.hashCode ^
        notes.hashCode ^
        guestEmail.hashCode ^
        guestPhone.hashCode;
  }

  @override
  String toString() {
    return 'Booking(id: $id, guestName: $guestName, checkIn: $formattedCheckIn, checkOut: $formattedCheckOut, source: ${source.toShortString()})';
  }
}

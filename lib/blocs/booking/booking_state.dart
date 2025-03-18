import 'package:equatable/equatable.dart';
import '../../models/booking.dart';

/// Base class for all booking-related states.
abstract class BookingState extends Equatable {
  const BookingState();

  @override
  List<Object?> get props => [];
}

/// Initial state when no bookings have been loaded.
class BookingInitial extends BookingState {}

/// State indicating that bookings are being loaded.
class BookingLoading extends BookingState {}

/// State with loaded bookings.
class BookingLoaded extends BookingState {
  final List<Booking> bookings;

  const BookingLoaded(this.bookings);

  @override
  List<Object> get props => [bookings];
}

/// State after a booking has been successfully created.
class BookingCreated extends BookingState {
  final Booking booking;

  const BookingCreated(this.booking);

  @override
  List<Object> get props => [booking];
}

/// State after a booking has been successfully updated.
class BookingUpdated extends BookingState {
  final Booking booking;

  const BookingUpdated(this.booking);

  @override
  List<Object> get props => [booking];
}

/// State after a booking has been successfully cancelled.
class BookingCancelled extends BookingState {
  final Booking booking;

  const BookingCancelled(this.booking);

  @override
  List<Object> get props => [booking];
}

/// State indicating that a booking overlaps with existing bookings.
class BookingOverlap extends BookingState {
  final List<Booking> overlappingBookings;

  const BookingOverlap(this.overlappingBookings);

  @override
  List<Object> get props => [overlappingBookings];
}

/// State indicating that a booking does not overlap with any existing bookings.
class BookingNoOverlap extends BookingState {}

/// State indicating an error in a booking operation.
class BookingError extends BookingState {
  final String message;

  const BookingError(this.message);

  @override
  List<Object> get props => [message];
}

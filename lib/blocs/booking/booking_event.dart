import 'package:equatable/equatable.dart';
import '../../models/booking.dart';

/// Base class for all booking-related events.
abstract class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

/// Event to fetch all bookings.
class FetchBookings extends BookingEvent {
  final DateTime? from;
  final DateTime? to;

  const FetchBookings({this.from, this.to});

  @override
  List<Object?> get props => [from, to];
}

/// Event to fetch bookings for a specific date.
class FetchBookingsByDate extends BookingEvent {
  final DateTime date;

  const FetchBookingsByDate(this.date);

  @override
  List<Object> get props => [date];
}

/// Event to create a new booking.
class CreateBooking extends BookingEvent {
  final Booking booking;

  const CreateBooking(this.booking);

  @override
  List<Object> get props => [booking];
}

/// Event to update an existing booking.
class UpdateBooking extends BookingEvent {
  final Booking booking;

  const UpdateBooking(this.booking);

  @override
  List<Object> get props => [booking];
}

/// Event to cancel a booking.
class CancelBooking extends BookingEvent {
  final Booking booking;

  const CancelBooking(this.booking);

  @override
  List<Object> get props => [booking];
}

/// Event triggered when bookings are updated from the repository stream.
class BookingsUpdated extends BookingEvent {
  final List<Booking> bookings;

  const BookingsUpdated(this.bookings);

  @override
  List<Object> get props => [bookings];
}

/// Event to check if a booking overlaps with existing bookings.
class CheckForOverlaps extends BookingEvent {
  final Booking booking;

  const CheckForOverlaps(this.booking);

  @override
  List<Object> get props => [booking];
}

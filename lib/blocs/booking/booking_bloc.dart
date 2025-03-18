import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'booking_event.dart';
import 'booking_state.dart';
import '../../models/booking.dart';
import '../../repositories/booking_repository.dart';

/// BLoC for managing booking-related state and events.
class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingRepository _repository;
  late StreamSubscription _bookingsSubscription;

  BookingBloc({required BookingRepository repository}) : _repository = repository, super(BookingInitial()) {
    on<FetchBookings>(_onFetchBookings);
    on<CreateBooking>(_onCreateBooking);
    on<UpdateBooking>(_onUpdateBooking);
    on<CancelBooking>(_onCancelBooking);
    on<BookingsUpdated>(_onBookingsUpdated);
    on<FetchBookingsByDate>(_onFetchBookingsByDate);
    on<CheckForOverlaps>(_onCheckForOverlaps);

    // Listen to the repository stream for updates
    _bookingsSubscription = _repository.bookingsStream.listen((bookings) {
      add(BookingsUpdated(bookings));
    });
  }

  Future<void> _onFetchBookings(FetchBookings event, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    try {
      final bookings = await _repository.fetchAllBookings(from: event.from, to: event.to);
      emit(BookingLoaded(bookings));
    } catch (e) {
      emit(BookingError('Failed to fetch bookings: $e'));
    }
  }

  Future<void> _onCreateBooking(CreateBooking event, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    try {
      final booking = await _repository.createManualBooking(event.booking);
      emit(BookingCreated(booking));
    } catch (e) {
      emit(BookingError('Failed to create booking: $e'));
    }
  }

  Future<void> _onUpdateBooking(UpdateBooking event, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    try {
      final booking = await _repository.updateBooking(event.booking);
      emit(BookingUpdated(booking));
    } catch (e) {
      emit(BookingError('Failed to update booking: $e'));
    }
  }

  Future<void> _onCancelBooking(CancelBooking event, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    try {
      final success = await _repository.cancelBooking(event.booking);
      if (success) {
        emit(BookingCancelled(event.booking));
      } else {
        emit(BookingError('Failed to cancel booking'));
      }
    } catch (e) {
      emit(BookingError('Failed to cancel booking: $e'));
    }
  }

  void _onBookingsUpdated(BookingsUpdated event, Emitter<BookingState> emit) {
    emit(BookingLoaded(event.bookings));
  }

  Future<void> _onFetchBookingsByDate(FetchBookingsByDate event, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    try {
      final bookings = await _repository.getBookingsByDate(event.date);
      emit(BookingLoaded(bookings));
    } catch (e) {
      emit(BookingError('Failed to fetch bookings: $e'));
    }
  }

  Future<void> _onCheckForOverlaps(CheckForOverlaps event, Emitter<BookingState> emit) async {
    try {
      final allBookings = await _repository.fetchAllBookings();

      // Add the potential new booking to the list to check against all
      final bookingsToCheck = List<Booking>.from(allBookings)..add(event.booking);

      final overlaps = _repository.findOverlappingBookings(bookingsToCheck);

      // Remove the new booking from the list of overlaps
      overlaps.remove(event.booking);

      if (overlaps.isNotEmpty) {
        emit(BookingOverlap(overlaps));
      } else {
        emit(BookingNoOverlap());
      }
    } catch (e) {
      emit(BookingError('Failed to check for overlaps: $e'));
    }
  }

  @override
  Future<void> close() {
    _bookingsSubscription.cancel();
    return super.close();
  }
}

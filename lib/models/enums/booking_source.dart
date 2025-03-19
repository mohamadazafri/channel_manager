enum BookingSource { manual, bookingDotCom, agoda, airbnb }

// Extension to add useful methods to the enum
extension BookingSourceExtension on BookingSource {
  String toShortString() {
    switch (this) {
      case BookingSource.manual:
        return 'manual';
      case BookingSource.bookingDotCom:
        return 'booking.com';
      case BookingSource.agoda:
        return 'agoda';
      case BookingSource.airbnb:
        return 'airbnb';
    }
  }

  String toDisplayString() {
    switch (this) {
      case BookingSource.manual:
        return 'Manual Entry';
      case BookingSource.bookingDotCom:
        return 'Booking.com';
      case BookingSource.agoda:
        return 'Agoda';
      case BookingSource.airbnb:
        return 'Airbnb';
    }
  }

  static BookingSource fromString(String source) {
    switch (source.toLowerCase()) {
      case 'manual':
        return BookingSource.manual;
      case 'booking.com':
        return BookingSource.bookingDotCom;
      case 'agoda':
        return BookingSource.agoda;
      case 'airbnb':
        return BookingSource.airbnb;
      default:
        return BookingSource.manual;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/booking.dart';
import '../../models/enums/booking_source.dart';

class OverlapAlertDialog extends StatelessWidget {
  final List<Booking> overlappingBookings;

  const OverlapAlertDialog({
    Key? key,
    required this.overlappingBookings,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Booking Conflicts Detected'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: overlappingBookings.length,
          itemBuilder: (context, index) {
            final booking = overlappingBookings[index];
            return ListTile(
              title: Text(booking.guestName),
              subtitle: Text(
                '${DateFormat('MMM dd').format(booking.checkIn)} - ${DateFormat('MMM dd').format(booking.checkOut)}',
              ),
              leading: CircleAvatar(
                backgroundColor: _getBookingColor(booking.source),
                child: const Icon(Icons.warning, color: Colors.white),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Review Later'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // User could implement conflict resolution logic
          },
          child: const Text('Resolve Now'),
        ),
      ],
    );
  }

  // Get color based on booking source
  Color _getBookingColor(BookingSource source) {
    switch (source) {
      case BookingSource.manual:
        return Colors.blue;
      case BookingSource.bookingDotCom:
        return Colors.deepPurple;
      case BookingSource.agoda:
        return Colors.red;
      case BookingSource.airbnb:
        return Colors.pink;
    }
  }
}

import 'package:flutter/material.dart';
import '../../models/booking.dart';
import '../../models/enums/booking_source.dart';

class BookingListItem extends StatelessWidget {
  final Booking booking;
  final VoidCallback? onTap;

  const BookingListItem({
    Key? key,
    required this.booking,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 4.0,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getBookingColor(booking.source),
          child: Icon(
            _getSourceIcon(booking.source),
            color: Colors.white,
          ),
        ),
        title: Text(
          booking.guestName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(booking.dateRange),
            Text(
              booking.source.toDisplayString(),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12.0,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!booking.isConfirmed)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Text(
                  'Pending',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.0,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: onTap,
            ),
          ],
        ),
        onTap: onTap,
      ),
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

  // Get icon based on booking source
  IconData _getSourceIcon(BookingSource source) {
    switch (source) {
      case BookingSource.manual:
        return Icons.edit;
      case BookingSource.bookingDotCom:
        return Icons.hotel;
      case BookingSource.agoda:
        return Icons.business;
      case BookingSource.airbnb:
        return Icons.house;
    }
  }
}

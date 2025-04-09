import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/booking/booking_bloc.dart';
import '../../blocs/booking/booking_event.dart';
import '../../blocs/booking/booking_state.dart';
import '../../models/booking.dart';
import '../../models/enums/booking_source.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Statistics
  int _totalUpcomingBookings = 0;
  int _totalCheckedIn = 0;
  double _monthlyRevenue = 0;
  double _yearlyRevenue = 0;
  Map<BookingSource, int> _bookingsBySource = {};

  // Sample room data - would come from your repository
  final List<Map<String, dynamic>> _rooms = [
    {'id': 'room1', 'name': 'Deluxe Room 101', 'price': 100},
    {'id': 'room2', 'name': 'Standard Room 102', 'price': 80},
    {'id': 'room3', 'name': 'Suite 201', 'price': 150},
  ];

  @override
  void initState() {
    super.initState();
    // Fetch initial bookings
    context.read<BookingBloc>().add(const FetchBookings());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Dashboard',
          style: TextStyle(
            color: Color(0xFF2E4057),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2E4057)),
      ),
      body: BlocConsumer<BookingBloc, BookingState>(
        listener: (context, state) {
          if (state is BookingLoaded) {
            _updateStatistics(state.bookings);
          }
        },
        builder: (context, state) {
          if (state is BookingInitial || state is BookingLoading) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            );
          } else if (state is BookingLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<BookingBloc>().add(const FetchBookings());
                // Wait for the refresh to complete
                return await Future.delayed(const Duration(seconds: 1));
              },
              color: Colors.blue[600],
              backgroundColor: Colors.white,
              strokeWidth: 2.5,
              displacement: 40,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: MediaQuery.of(context).padding.bottom + 100.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    _buildRevenueChart(),
                    const SizedBox(height: 24),
                    _buildBookingSourceChart(),
                    const SizedBox(height: 24),
                    _buildRecentBookings(state.bookings),
                  ],
                ),
              ),
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load dashboard data',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.read<BookingBloc>().add(const FetchBookings());
                    },
                    style: ElevatedButton.styleFrom(
                      textStyle: TextStyle(color: Colors.blue[600]),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          title: 'Upcoming Check-ins',
          value: _totalUpcomingBookings.toString(),
          icon: Icons.event_available,
          color: Colors.blue[600]!,
        ),
        _buildStatCard(
          title: 'Currently Checked In',
          value: _totalCheckedIn.toString(),
          icon: Icons.hotel,
          color: Colors.green[600]!,
        ),
        _buildStatCard(
          title: 'Monthly Revenue',
          value: '\$${_monthlyRevenue.toStringAsFixed(2)}',
          icon: Icons.payments,
          color: Colors.amber[600]!,
        ),
        _buildStatCard(
          title: 'Annual Revenue',
          value: '\$${_yearlyRevenue.toStringAsFixed(2)}',
          icon: Icons.account_balance,
          color: Colors.purple[600]!,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.grey[900],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    // This would be better implemented with a charting library like fl_chart or charts_flutter
    // Here we're using a simple implementation for demonstration

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: (_monthlyRevenue / (_yearlyRevenue > 0 ? _yearlyRevenue : 1)) * 120,
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'This Month',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_monthlyRevenue.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.purple[600],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'This Year',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${_yearlyRevenue.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingSourceChart() {
    // Simplified chart implementation
    // Would be better with a proper charting library

    final total = _bookingsBySource.values.fold<int>(0, (sum, count) => sum + count);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking Sources',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 24),
            ...BookingSource.values.map((source) {
              final count = _bookingsBySource[source] ?? 0;
              final percent = total > 0 ? count / total * 100 : 0;
              final color = _getBookingSourceColor(source);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          source.toDisplayString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '$count (${percent.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 6,
                          width: (percent / 100) * (MediaQuery.of(context).size.width - 72),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentBookings(List<Booking> allBookings) {
    // Sort bookings by check-in date (most recent first)
    final recentBookings = List<Booking>.from(allBookings)..sort((a, b) => b.checkIn.compareTo(a.checkIn));

    // Take only the 5 most recent bookings
    final bookingsToShow = recentBookings.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Bookings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to bookings tab
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    TabNavigator.navigateToTab(0); // Assuming bookings tab is index 0
                  },
                  style: TextButton.styleFrom(
                    textStyle: TextStyle(color: Colors.blue[600]),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (bookingsToShow.isEmpty)
              Container(
                height: 100,
                alignment: Alignment.center,
                child: Text(
                  'No recent bookings',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              )
            else
              ...bookingsToShow.map((booking) => _buildRecentBookingItem(booking)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentBookingItem(Booking booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _getBookingSourceColor(booking.source),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.guestName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${booking.dateRange} · ${booking.source.toDisplayString()}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: booking.isConfirmed ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: booking.isConfirmed ? Colors.green[200]! : Colors.orange[200]!,
                width: 1,
              ),
            ),
            child: Text(
              booking.isConfirmed ? 'Confirmed' : 'Pending',
              style: TextStyle(
                color: booking.isConfirmed ? Colors.green[700] : Colors.orange[700],
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBookingSourceColor(BookingSource source) {
    switch (source) {
      case BookingSource.manual:
        return Colors.blue[600]!;
      case BookingSource.bookingDotCom:
        return Colors.deepPurple[600]!;
      case BookingSource.agoda:
        return Colors.red[600]!;
      case BookingSource.airbnb:
        return Colors.pink[600]!;
    }
  }

  void _updateStatistics(List<Booking> bookings) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    int upcomingBookings = 0;
    int checkedIn = 0;
    double monthlyRevenue = 0;
    double yearlyRevenue = 0;
    Map<BookingSource, int> bookingsBySource = {
      BookingSource.manual: 0,
      BookingSource.bookingDotCom: 0,
      BookingSource.agoda: 0,
      BookingSource.airbnb: 0,
    };

    for (var booking in bookings) {
      // Check upcoming bookings (check-in today or in the future)
      if (booking.checkIn.isAfter(today) ||
          (booking.checkIn.day == today.day && booking.checkIn.month == today.month && booking.checkIn.year == today.year)) {
        upcomingBookings++;
      }

      // Check currently checked in
      if (booking.checkIn.isBefore(tomorrow) && booking.checkOut.isAfter(today)) {
        checkedIn++;
      }

      // Calculate revenue (assuming booking.checkOut is in the past)
      if (booking.checkOut.isAfter(monthStart)) {
        // Get room price
        final roomPrice = _getRoomPrice(booking.roomId);
        final days = booking.durationInDays;
        monthlyRevenue += roomPrice * days;
      }

      if (booking.checkOut.isAfter(yearStart)) {
        // Get room price
        final roomPrice = _getRoomPrice(booking.roomId);
        final days = booking.durationInDays;
        yearlyRevenue += roomPrice * days;
      }

      // Count bookings by source
      bookingsBySource[booking.source] = (bookingsBySource[booking.source] ?? 0) + 1;
    }

    setState(() {
      _totalUpcomingBookings = upcomingBookings;
      _totalCheckedIn = checkedIn;
      _monthlyRevenue = monthlyRevenue;
      _yearlyRevenue = yearlyRevenue;
      _bookingsBySource = bookingsBySource;
    });
  }

  double _getRoomPrice(String roomId) {
    final room = _rooms.firstWhere((room) => room['id'] == roomId, orElse: () => {'price': 0});
    return room['price'].toDouble();
  }
}

// Helper class for tab navigation
class TabNavigator {
  static GlobalKey<NavigatorState> tabNavigatorKey = GlobalKey<NavigatorState>();
  static int _currentIndex = 0;

  static void navigateToTab(int index) {
    _currentIndex = index;
    // This is just a placeholder - you'll need to implement the actual tab navigation logic
    // in your app's main navigation structure
  }
}

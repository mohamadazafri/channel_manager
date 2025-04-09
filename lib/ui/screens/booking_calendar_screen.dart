import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';
import '../../blocs/booking/booking_bloc.dart';
import '../../blocs/booking/booking_event.dart';
import '../../blocs/booking/booking_state.dart';
import '../../models/booking.dart';
import '../../models/enums/booking_source.dart';
import '../widgets/overlap_alert_dialog.dart';
import 'booking_form_screen.dart';

class BookingCalendarScreen extends StatefulWidget {
  const BookingCalendarScreen({Key? key}) : super(key: key);

  @override
  _BookingCalendarScreenState createState() => _BookingCalendarScreenState();
}

class _BookingCalendarScreenState extends State<BookingCalendarScreen> {
  final GlobalKey _todaySectionKey = GlobalKey();
  final GlobalKey _upcomingSectionKey = GlobalKey();
  final GlobalKey _roomsSectionKey = GlobalKey();
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Booking> _filteredBookings = [];
  List<Booking> _lastBookings = [];
  String? _selectedRoomFilter;
  DateTimeRange? _dateRangeFilter;
  bool _isFilterActive = false;
  List<DateTime>? _blackoutDates = [];
  late DateRangePickerController _dateRangePickerController;
  PickerDateRange? _selectedRange;
  List<Booking> _bookings = [];
  int _selectedTabIndex = 0;
  // Map to track expanded room cards
  Map<String, bool> _expandedRooms = {};

  // Room availability
  Map<String, bool> _roomAvailability = {};

  // Map to store bookings by room ID for the selected date range
  Map<String, Booking?> _roomBookings = {};

  // Sample room data - would come from your repository
  final List<Map<String, dynamic>> _rooms = [
    {'id': 'room1', 'name': 'Deluxe Room 101', 'price': 100},
    {'id': 'room2', 'name': 'Standard Room 102', 'price': 80},
    {'id': 'room3', 'name': 'Suite 201', 'price': 150},
  ];

  @override
  void initState() {
    super.initState();
    _dateRangePickerController = DateRangePickerController();
    _dateRangePickerController.selectedRange = PickerDateRange(
      DateTime.now(),
      DateTime.now().add(const Duration(days: 3)),
    );
    _selectedRange = _dateRangePickerController.selectedRange;

    // Initialize room availability and expanded state
    for (var room in _rooms) {
      _roomAvailability[room['id']] = true;
      _expandedRooms[room['id']] = false;
      _roomBookings[room['id']] = null;
    }

    // Fetch initial bookings
    context.read<BookingBloc>().add(const FetchBookings());

    _updateRoomBookings();
  }

  @override
  void dispose() {
    _dateRangePickerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            title: const Text(
              'Bookings',
              style: TextStyle(
                color: Color(0xFF2E4057),
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            bottom: TabBar(
              indicatorColor: Colors.blue[600],
              labelColor: Colors.blue[700],
              unselectedLabelColor: Colors.grey[600],
              tabs: const [
                Tab(
                  icon: Icon(Icons.calendar_month),
                  text: 'Calendar',
                ),
                Tab(
                  icon: Icon(Icons.list_alt),
                  text: 'All Bookings',
                ),
              ],
              onTap: (index) {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
            ),
            actions: [
              // Only show filter button on All Bookings tab
              if (_selectedTabIndex == 1)
                IconButton(
                  icon: const Icon(
                    Icons.filter_list,
                    color: Color(0xFF2E4057),
                  ),
                  tooltip: 'Filter Bookings',
                  onPressed: () {
                    _showFilterDialog();
                  },
                ),
            ],
            iconTheme: const IconThemeData(color: Color(0xFF2E4057)),
          ),
          body: BlocConsumer<BookingBloc, BookingState>(
            listener: (context, state) {
              if (state is BookingOverlap) {
                showDialog(
                  context: context,
                  builder: (context) => OverlapAlertDialog(
                    overlappingBookings: state.overlappingBookings,
                  ),
                );
              } else if (state is BookingCancelled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Booking for ${state.booking.guestName} has been cancelled'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else if (state is BookingError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message)),
                );
              } else if (state is BookingLoaded) {
                setState(() {
                  _bookings = state.bookings;
                  _updateRoomBookings();
                  _updateBlackoutDates();
                });
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
                return TabBarView(
                  children: [
                    // Calendar Tab
                    RefreshIndicator(
                      onRefresh: () async {
                        context.read<BookingBloc>().add(const FetchBookings());
                        return await Future.delayed(const Duration(seconds: 1));
                      },
                      color: Colors.blue[600],
                      backgroundColor: Colors.white,
                      strokeWidth: 2.5,
                      displacement: 40,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 16.0,
                            right: 16.0,
                            top: 8.0,
                            bottom: MediaQuery.of(context).padding.bottom + 100.0,
                          ),
                          child: _buildCalendarWithAvailability(),
                        ),
                      ),
                    ),

                    // All Bookings Tab
                    RefreshIndicator(
                      onRefresh: () async {
                        context.read<BookingBloc>().add(const FetchBookings());
                        return await Future.delayed(const Duration(seconds: 1));
                      },
                      color: Colors.blue[600],
                      backgroundColor: Colors.white,
                      strokeWidth: 2.5,
                      displacement: 40,
                      child: _buildBookingsList(state.bookings),
                    ),
                  ],
                );
              } else {
                // Existing error state handling...
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load bookings',
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
        ));
  }

  Widget _buildCalendarWithAvailability() {
    final formatter = DateFormat('MMM dd, yyyy');

    String dateRangeText = '';
    if (_selectedRange != null && _selectedRange!.startDate != null) {
      if (_selectedRange!.endDate != null) {
        dateRangeText = '${formatter.format(_selectedRange!.startDate!)} - ${formatter.format(_selectedRange!.endDate!)}';
      } else {
        dateRangeText = formatter.format(_selectedRange!.startDate!);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Calendar Container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Calendar header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select Dates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ),

              // Date picker
              Container(
                height: 350,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SfDateRangePicker(
                  controller: _dateRangePickerController,
                  view: DateRangePickerView.month,
                  selectionMode: DateRangePickerSelectionMode.range,
                  initialDisplayDate: DateTime.now(),
                  initialSelectedRange: PickerDateRange(
                    DateTime.now(),
                    DateTime.now().add(const Duration(days: 3)),
                  ),
                  minDate: DateTime.now(), // Add this line to prevent selecting past dates
                  monthViewSettings: const DateRangePickerMonthViewSettings(
                    // blackoutDates: _blackoutDates,
                    firstDayOfWeek: 1,
                    showTrailingAndLeadingDates: false,
                    dayFormat: 'EEE',
                    viewHeaderStyle: const DateRangePickerViewHeaderStyle(
                      textStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ),
                  headerStyle: const DateRangePickerHeaderStyle(
                    textAlign: TextAlign.center,
                    textStyle: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E4057),
                    ),
                  ),
                  monthCellStyle: DateRangePickerMonthCellStyle(
                    textStyle: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF555555),
                    ),
                    todayTextStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                    todayCellDecoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue, width: 1),
                      shape: BoxShape.circle,
                    ),
                    // blackoutDateTextStyle:
                    //     TextStyle(color: Colors.red[300], decoration: TextDecoration.lineThrough, decorationColor: Colors.red[300]),
                  ),

                  rangeSelectionColor: Colors.blue.shade100.withOpacity(0.4),
                  selectionColor: Colors.blue[600],
                  startRangeSelectionColor: Colors.blue[600],
                  endRangeSelectionColor: Colors.blue[600],
                  selectionRadius: 20,
                  onSelectionChanged: (DateRangePickerSelectionChangedArgs args) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          if (args.value is PickerDateRange) {
                            final newRange = args.value as PickerDateRange;

                            // Handle same day selection - make it a 1-night stay
                            if (newRange.startDate != null &&
                                newRange.endDate != null &&
                                newRange.startDate!.year == newRange.endDate!.year &&
                                newRange.startDate!.month == newRange.endDate!.month &&
                                newRange.startDate!.day == newRange.endDate!.day) {
                              // Create a new range with end date as the next day
                              _selectedRange = PickerDateRange(
                                newRange.startDate,
                                newRange.startDate!.add(const Duration(days: 1)),
                              );
                            } else {
                              _selectedRange = newRange;
                            }

                            _updateRoomBookings();
                          }
                        });
                      }
                    });
                  },
                ),
              ),

              // Visual divider
              Divider(
                color: Colors.grey[200],
                height: 1,
                thickness: 1,
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Room Availability header with icon
                    Row(
                      children: [
                        Icon(Icons.hotel, color: Colors.grey[800], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Room Availability',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            '${_getNightsCount()} ${_getNightsCount() == 1 ? 'night' : 'nights'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Date range display with calendar icon
                    if (_selectedRange != null && _selectedRange!.startDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 18, color: Colors.grey[800]),
                            const SizedBox(width: 8),
                            Text(
                              _selectedRange!.endDate != null
                                  ? '${DateFormat('MMM dd, yyyy').format(_selectedRange!.startDate!)} - ${DateFormat('MMM dd, yyyy').format(_selectedRange!.endDate!)}'
                                  : DateFormat('MMM dd, yyyy').format(_selectedRange!.startDate!),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Available rooms display with hotel icon - make this stand out more
                    InkWell(
                      onTap: () {
                        // Scroll to the Rooms section
                        Scrollable.ensureVisible(
                          _roomsSectionKey.currentContext!,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      },
                      borderRadius: BorderRadius.circular(8), // Match container's border radius
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: _getAvailabilityColor(),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _getAvailabilityBorderColor()),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.meeting_room,
                              size: 18,
                              color: _getAvailabilityTextColor(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_roomAvailability.values.where((available) => available).length} of ${_roomAvailability.length} rooms available',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: _getAvailabilityTextColor(),
                                ),
                              ),
                            ),
                            // Add a small icon to indicate this is clickable
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: _getAvailabilityTextColor(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          key: _roomsSectionKey, // Add the key here
          padding: const EdgeInsets.fromLTRB(4.0, 20.0, 4.0, 16.0),
          child: Row(
            children: [
              Icon(
                Icons.hotel_outlined,
                size: 22,
                color: Colors.grey[800],
              ),
              const SizedBox(width: 8),
              Text(
                'Rooms',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
        ),

        // Room availability list
        ...(_rooms.map((room) {
          final roomId = room['id'];
          final isAvailable = _roomAvailability[roomId] ?? true;
          final isExpanded = _expandedRooms[roomId] ?? false;
          final booking = _roomBookings[roomId];

          final nightCount = _selectedRange != null && _selectedRange!.endDate != null
              ? _selectedRange!.endDate!.difference(_selectedRange!.startDate!).inDays + 1
              : 1;

          return GestureDetector(
            onTap: isAvailable ? () => _navigateToBookingForm(room) : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Room card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: isExpanded ? const BorderRadius.vertical(top: Radius.circular(16)) : BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Room header
                          Row(
                            children: [
                              Icon(
                                Icons.hotel,
                                color: isAvailable ? Colors.green[600] : Colors.red[600],
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                room['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isAvailable ? Colors.green[50] : Colors.red[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isAvailable ? Colors.green[200]! : Colors.red[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  isAvailable ? 'Available' : 'Booked',
                                  style: TextStyle(
                                    color: isAvailable ? Colors.green[700] : Colors.red[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Room pricing
                          Padding(
                            padding: const EdgeInsets.only(left: 36, top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '\$${room['price']} per night',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                                if (_selectedRange != null && _selectedRange!.endDate != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Total: \$${(room['price'] * nightCount).toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Book now button for available rooms
                          if (isAvailable)
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _navigateToBookingForm(room),
                                    style: ElevatedButton.styleFrom(
                                      // Use a more vibrant blue color
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                      // Add elevation for depth
                                      elevation: 2,
                                      shadowColor: Colors.blue.withOpacity(0.5),
                                      // Add more generous padding for a larger, more tappable button
                                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                                      // Rounded corners that match your app's style
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Book Now',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Booking details button (only for booked rooms)
                          if (!isAvailable && booking != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _expandedRooms[roomId] = !isExpanded;
                                  });
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isExpanded ? 'Hide details' : 'Show booking details',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                      color: Colors.blue[700],
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Expanded details section
                  if (!isAvailable && isExpanded && booking != null)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Guest details
                          Text(
                            'Guest Details',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Details grid
                          Wrap(
                            spacing: 24,
                            runSpacing: 16,
                            children: [
                              _buildDetailItem('Guest', booking.guestName),
                              _buildDetailItem('Check-in', booking.formattedCheckIn),
                              _buildDetailItem('Check-out', booking.formattedCheckOut),
                              _buildDetailItem('Source', booking.source.toDisplayString()),
                              _buildDetailItem('Status', booking.isConfirmed ? 'Confirmed' : 'Pending'),
                              if (booking.guestEmail != null) _buildDetailItem('Email', booking.guestEmail!),
                              if (booking.guestPhone != null) _buildDetailItem('Phone', booking.guestPhone!),
                            ],
                          ),

                          // Notes section if available
                          if (booking.notes != null && booking.notes!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Notes',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Text(
                                booking.notes!,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],

                          // Action buttons
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit'),
                                onPressed: () => _editBooking(booking),
                                style: OutlinedButton.styleFrom(
                                  textStyle: TextStyle(color: Colors.blue[700]),
                                  side: BorderSide(color: Colors.blue[700]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.delete, size: 16),
                                label: const Text('Cancel'),
                                onPressed: () => _showCancellationConfirmation(booking),
                                style: OutlinedButton.styleFrom(
                                  textStyle: TextStyle(color: Colors.red[700]),
                                  side: BorderSide(color: Colors.red[300]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList()),
      ],
    );
  }

  List<DateTime> _getBlackoutDates() {
    // If we don't have bookings data yet, return empty list
    if (_bookings.isEmpty) {
      return [];
    }

    // Create a map to track room availability for each date
    // Keys are date strings in format 'yyyy-MM-dd', values are counts of available rooms
    Map<String, int> dateAvailability = {};

    // Calculate date range to check (today + 1 year)
    final today = DateTime.now();
    final oneYearLater = today.add(const Duration(days: 365));

    // Initialize all dates with full availability
    DateTime currentDay = today;
    while (currentDay.isBefore(oneYearLater)) {
      final dateString = DateFormat('yyyy-MM-dd').format(currentDay);
      dateAvailability[dateString] = _rooms.length; // All rooms available initially
      currentDay = currentDay.add(const Duration(days: 1));
    }

    // Update availability based on bookings
    for (var booking in _bookings) {
      // Skip past bookings
      if (booking.checkOut.isBefore(today)) {
        continue;
      }

      // Mark room as unavailable for each day of the booking
      DateTime bookingDay = booking.checkIn;

      // Only count until checkout date (exclusive) since checkout day can be booked by someone else
      while (bookingDay.isBefore(booking.checkOut)) {
        final dateString = DateFormat('yyyy-MM-dd').format(bookingDay);

        // If this date is within our date range, update availability
        if (dateAvailability.containsKey(dateString)) {
          dateAvailability[dateString] = dateAvailability[dateString]! - 1;
        }

        bookingDay = bookingDay.add(const Duration(days: 1));
      }
    }

    // Collect dates with zero availability (fully booked)
    List<DateTime> blackoutDates = [];
    dateAvailability.forEach((dateString, availableRooms) {
      if (availableRooms <= 0) {
        // Parse the date string back to DateTime
        blackoutDates.add(DateFormat('yyyy-MM-dd').parse(dateString));
      }
    });

    return blackoutDates;
  }

  Widget _buildDetailItem(String label, String value) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _updateRoomBookings() {
    if (_bookings.isEmpty || _selectedRange == null || _selectedRange!.startDate == null) {
      // If no date range is selected, all rooms are available
      for (var room in _rooms) {
        _roomAvailability[room['id']] = true;
        _roomBookings[room['id']] = null;
      }
      return;
    }

    // Reset all rooms to available
    for (var room in _rooms) {
      _roomAvailability[room['id']] = true;
      _roomBookings[room['id']] = null;
    }

    final startDate = _selectedRange!.startDate!;
    final endDate = _selectedRange!.endDate ?? startDate;

    // Check each booking to see if it overlaps with the selected date range
    for (var booking in _bookings) {
      // If the booking overlaps with the selected date range, mark the room as unavailable
      if (!booking.checkIn.isAfter(endDate) && booking.checkOut.isAfter(startDate)) {
        _roomAvailability[booking.roomId] = false;
        _roomBookings[booking.roomId] = booking;
      }
    }
  }

  int _getNightsCount() {
    if (_selectedRange == null || _selectedRange!.startDate == null) {
      return 0;
    }

    if (_selectedRange!.endDate == null) {
      // When only start date is selected, consider it as 1 night
      return 1;
    }

    // Calculate nights between the dates
    return _selectedRange!.endDate!.difference(_selectedRange!.startDate!).inDays;
  }

  void _navigateToBookingForm(Map<String, dynamic> room) {
    // Get the BlocProvider at the current level
    final BookingBloc bookingBloc = BlocProvider.of<BookingBloc>(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider<BookingBloc>.value(
          value: bookingBloc, // Pass the instance directly instead of using context.read
          child: BookingFormScreen(
            initialRoom: room['id'],
            initialDates: _selectedRange != null && _selectedRange!.startDate != null
                ? DateTimeRange(
                    start: _selectedRange!.startDate!,
                    end: _selectedRange!.endDate ?? _selectedRange!.startDate!.add(const Duration(days: 1)),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  void _editBooking(Booking booking) {
    final BookingBloc bookingBloc = BlocProvider.of<BookingBloc>(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider<BookingBloc>.value(
          value: bookingBloc,
          child: BookingFormScreen(booking: booking),
        ),
      ),
    );
  }

  void _showCancellationConfirmation(Booking booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Cancel Booking',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel the booking for ${booking.guestName}?',
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking Details:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCancellationDetailItem('Check-in', booking.formattedCheckIn),
                  _buildCancellationDetailItem('Check-out', booking.formattedCheckOut),
                  _buildCancellationDetailItem('Source', booking.source.toDisplayString()),
                  _buildCancellationDetailItem('Guest', booking.guestName),
                ],
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
            child: const Text('KEEP BOOKING'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processCancelBooking(booking);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('CONFIRM CANCELLATION'),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      ),
    );
  }

  Widget _buildCancellationDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _processCancelBooking(Booking booking) {
    // Show white-themed loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                ),
                const SizedBox(width: 20),
                Text(
                  "Cancelling booking...",
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // Dispatch the cancel event
    context.read<BookingBloc>().add(CancelBooking(booking));

    // Close the loading dialog after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      Navigator.pop(context);
    });
  }

  Widget _buildBookingsList(List<Booking> bookings) {
    // First, make sure we have the latest bookings and filters applied
    if (_lastBookings != bookings) {
      _lastBookings = bookings;
      _filteredBookings = _applyFilters(bookings);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Always maintain the Today/Upcoming sections
    final todayBookings = _filteredBookings.where((booking) {
      final checkInDate = DateTime(booking.checkIn.year, booking.checkIn.month, booking.checkIn.day);
      return checkInDate.isAtSameMomentAs(today) || (booking.checkIn.isBefore(now) && booking.checkOut.isAfter(now));
    }).toList();

    final upcomingBookings = _filteredBookings.where((booking) {
      final checkInDate = DateTime(booking.checkIn.year, booking.checkIn.month, booking.checkIn.day);
      return checkInDate.isAfter(today);
    }).toList();

    // Sort the upcoming bookings by check-in date
    upcomingBookings.sort((a, b) => a.checkIn.compareTo(b.checkIn));

    // For debugging, print out each booking in the filtered results
    print("Filtered results (${_filteredBookings.length} total):");
    for (var booking in _filteredBookings) {
      print(
          " - ${booking.id.substring(0, 8)} | ${booking.guestName} | Room: ${_getRoomName(booking.roomId)} | ${booking.checkIn.toString().substring(0, 10)}");
    }

    print("Today: ${todayBookings.length} bookings, Upcoming: ${upcomingBookings.length} bookings");

    // Check if we have any bookings to display
    final hasAnyBookings = todayBookings.isNotEmpty || upcomingBookings.isNotEmpty;
    final hasFilteredBookings = _filteredBookings.isNotEmpty;

    final isSearching = _searchQuery.isNotEmpty;
    final isFiltering = _selectedRoomFilter != null || _dateRangeFilter != null;

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Row(
            children: [
              // Search bar
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or ID',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _filterBookings(bookings);
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _filterBookings(bookings);
                      });
                    },
                  ),
                ),
              ),

              // Filter button
              Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: _isFilterActive ? Colors.blue[600] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: _isFilterActive ? Colors.white : Colors.grey[700],
                  ),
                  tooltip: 'Filter Bookings',
                  onPressed: _showFilterOptions,
                ),
              ),
            ],
          ),
        ),

// Also, add a filter indicator if filters are active
        if (_isFilterActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Room filter chip
                  if (_selectedRoomFilter != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        label: Text(
                          'Room: ${_getRoomName(_selectedRoomFilter!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                        backgroundColor: Colors.blue[50],
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _selectedRoomFilter = null;
                            _isFilterActive = _dateRangeFilter != null;
                            _updateFilters();
                          });
                        },
                      ),
                    ),

                  // Date range filter chip
                  if (_dateRangeFilter != null)
                    Chip(
                      label: Text(
                        'Dates: ${DateFormat('MMM dd').format(_dateRangeFilter!.start)} - ${DateFormat('MMM dd').format(_dateRangeFilter!.end)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                      backgroundColor: Colors.blue[50],
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() {
                          _dateRangeFilter = null;
                          _isFilterActive = _selectedRoomFilter != null;
                          _updateFilters();
                        });
                      },
                    ),

                  // Clear all filters button
                  if (_hasActiveFilters)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedRoomFilter = null;
                          _dateRangeFilter = null;
                          _isFilterActive = false;
                          _updateFilters();
                        });
                      },
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        // Quick navigation buttons - only show if we have any filtered bookings
        if (todayBookings.isNotEmpty || upcomingBookings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0), // Added more bottom padding
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
                // Add a subtle border to make it stand out
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10.0), // Slightly more padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Add a title to clearly identify this as navigation
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Text(
                        "Quick Navigation",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.today, size: 18),
                            label: Text(
                              'Today (${todayBookings.length})',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onPressed: todayBookings.isEmpty
                                ? null
                                : () {
                                    Scrollable.ensureVisible(
                                      _todaySectionKey.currentContext!,
                                      duration: const Duration(milliseconds: 500),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              // Make the button more distinct
                              backgroundColor: Colors.teal[100],
                              foregroundColor: Colors.teal[900],
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontSize: 14),
                              // Distinct disabled style
                              disabledBackgroundColor: Colors.grey[200],
                              disabledForegroundColor: Colors.grey[500],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.event, size: 18),
                            label: Text(
                              'Upcoming (${upcomingBookings.length})',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onPressed: upcomingBookings.isEmpty
                                ? null
                                : () {
                                    Scrollable.ensureVisible(
                                      _upcomingSectionKey.currentContext!,
                                      duration: const Duration(milliseconds: 500),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              // Make the button more distinct
                              backgroundColor: Colors.blue[100],
                              foregroundColor: Colors.blue[900],
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              textStyle: const TextStyle(fontSize: 14),
                              disabledBackgroundColor: Colors.grey[200],
                              disabledForegroundColor: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (isSearching)
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 8.0),
            child: Row(
              children: [
                Text(
                  'Found ${_filteredBookings.length} result${_filteredBookings.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

        // Main content with sections
        Expanded(
          child: !hasFilteredBookings && (isSearching || isFiltering)
              // Show "No results" when filtering with no matches
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No matches found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try different search terms or filters',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 100.0,
                    top: 8.0,
                  ),
                  children: [
                    // Today section
                    Container(
                      key: _todaySectionKey,
                      child: _buildSectionHeader('Today', todayBookings.length),
                    ),

                    if (todayBookings.isNotEmpty)
                      ...todayBookings.map((booking) => _buildBookingListItem(booking, today))
                    else
                      // Empty today section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event_available, color: Colors.grey[400], size: 24),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isSearching || isFiltering ? 'No matches for today' : 'No arrivals today',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isSearching || isFiltering ? 'Try different search criteria' : 'Your schedule is clear for today',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Upcoming section
                    Container(
                      key: _upcomingSectionKey,
                      child: _buildSectionHeader('Upcoming', upcomingBookings.length),
                    ),

                    if (upcomingBookings.isNotEmpty)
                      ...upcomingBookings.map((booking) => _buildBookingListItem(booking, today))
                    else
                      // Empty upcoming section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event_busy, color: Colors.grey[400], size: 24),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isSearching || isFiltering ? 'No upcoming matches' : 'No upcoming bookings',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isSearching || isFiltering ? 'Try different search criteria' : 'You have no future reservations scheduled',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0), // More top padding
      child: Row(
        children: [
          // Add an icon to make it more distinct
          Icon(
            title == "Today" ? Icons.today : Icons.date_range,
            size: 22,
            color: title == "Today" ? Colors.teal[700] : Colors.blue[700],
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: title == "Today" ? Colors.teal[800] : Colors.blue[800],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: title == "Today" ? Colors.teal[100] : Colors.blue[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: title == "Today" ? Colors.teal[700] : Colors.blue[700],
              ),
            ),
          ),
          // Add a line to make the header more distinct
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 10),
              height: 1,
              color: title == "Today" ? Colors.teal[200] : Colors.blue[200],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingListItem(Booking booking, DateTime today) {
    final now = DateTime.now();
    final isActive = !booking.checkOut.isBefore(now);
    final isPast = booking.checkOut.isBefore(now);
    final isCheckedIn = booking.checkIn.isBefore(now) && booking.checkOut.isAfter(now);

    // Calculate days until arrival
    final checkInDate = DateTime(booking.checkIn.year, booking.checkIn.month, booking.checkIn.day);
    final daysUntilArrival = checkInDate.difference(today).inDays;

    // Define arrival status text and color
    String arrivalStatus;
    Color arrivalColor;
    bool isArrivingTomorrow = daysUntilArrival == 1;

    if (isCheckedIn) {
      arrivalStatus = "Currently staying";
      arrivalColor = Colors.green[700]!;
    } else if (daysUntilArrival == 0) {
      arrivalStatus = "Arriving today";
      arrivalColor = Colors.orange[700]!;
    } else if (isArrivingTomorrow) {
      arrivalStatus = "Arriving tomorrow";
      arrivalColor = Colors.blue[800]!; // Deeper blue for emphasis without being alarming
    } else if (daysUntilArrival > 0) {
      arrivalStatus = "Arriving in $daysUntilArrival days";
      arrivalColor = Colors.blue[700]!;
    } else {
      arrivalStatus = "Past booking";
      arrivalColor = Colors.grey[600]!;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Slightly higher elevation for tomorrow's arrivals
      elevation: isArrivingTomorrow ? 3 : 2,
      // Add a subtle border for tomorrow's arrivals
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isArrivingTomorrow ? BorderSide(color: Colors.blue[300]!, width: 1.5) : BorderSide(color: Colors.grey[300]!, width: 0.5),
      ),
      // Add a subtle background color for tomorrow's arrivals
      color: isArrivingTomorrow ? Colors.blue[50] : Colors.white,
      child: InkWell(
        onTap: () {
          _showBookingDetailsBottomSheet(booking);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      booking.id.substring(0, 8), // Show abbreviated ID
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 8),
              // Add a subtle top banner for tomorrow arrivals
              if (isArrivingTomorrow)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available, size: 18, color: Colors.blue[800]),
                      const SizedBox(width: 8),
                      Text(
                        'Prep Needed: Arriving Tomorrow',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[800],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status dot
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCheckedIn
                          ? Colors.green[600]
                          : isPast
                              ? Colors.grey[400]
                              : isArrivingTomorrow
                                  ? Colors.blue[700]
                                  : Colors.blue[600],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.guestName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${booking.dateRange} · ${booking.durationInDays} ${booking.durationInDays == 1 ? 'night' : 'nights'}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Arrival status badge - make tomorrow's arrival more prominent
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: arrivalColor.withOpacity(isArrivingTomorrow ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: arrivalColor.withOpacity(isArrivingTomorrow ? 0.4 : 0.3),
                              width: isArrivingTomorrow ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            arrivalStatus,
                            style: TextStyle(
                              color: arrivalColor,
                              fontWeight: isArrivingTomorrow ? FontWeight.w600 : FontWeight.w500,
                              fontSize: isArrivingTomorrow ? 13 : 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getBookingSourceColor(booking.source).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          booking.source.toDisplayString(),
                          style: TextStyle(
                            color: _getBookingSourceColor(booking.source),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!booking.isConfirmed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Text(
                            'Pending',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 8),
                child: Text(
                  'Room: ${_getRoomName(booking.roomId)}',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                  ),
                ),
              ),

              // Add preparation reminder for tomorrow's arrivals with a more subtle design
              if (isArrivingTomorrow)
                Container(
                  margin: const EdgeInsets.only(top: 12, left: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.amber[800]),
                      const SizedBox(width: 6),
                      Text(
                        'Room preparation needed',
                        style: TextStyle(
                          color: Colors.amber[800],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoomName(String roomId) {
    final room = _rooms.firstWhere(
      (room) => room['id'] == roomId,
      orElse: () => {'name': 'Unknown Room'},
    );
    return room['name'];
  }

  void _showBookingDetailsBottomSheet(Booking booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.grey[800],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                'Booking ID: ${booking.id.substring(0, 8)}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontFamily: 'monospace', // Use monospace font for IDs
                ),
              ),
            ),

            const SizedBox(height: 24),
            // Guest details section
            _buildDetailSectionHeader('Guest Information'),
            const SizedBox(height: 12),
            _buildDetailRow('Name', booking.guestName),
            if (booking.guestEmail != null && booking.guestEmail!.isNotEmpty) _buildDetailRow('Email', booking.guestEmail!),
            if (booking.guestPhone != null && booking.guestPhone!.isNotEmpty) _buildDetailRow('Phone', booking.guestPhone!),

            const SizedBox(height: 24),
            // Booking details section
            _buildDetailSectionHeader('Booking Information'),
            const SizedBox(height: 12),
            _buildDetailRow('Check-in', booking.formattedCheckIn),
            _buildDetailRow('Check-out', booking.formattedCheckOut),
            _buildDetailRow('Duration', '${booking.durationInDays} ${booking.durationInDays == 1 ? 'night' : 'nights'}'),
            _buildDetailRow('Room', _getRoomName(booking.roomId)),
            _buildDetailRow('Source', booking.source.toDisplayString()),
            _buildDetailRow('Status', booking.isConfirmed ? 'Confirmed' : 'Pending'),

            if (booking.notes != null && booking.notes!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildDetailSectionHeader('Notes'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  booking.notes!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],

            const SizedBox(height: 24),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    onPressed: () {
                      Navigator.pop(context);
                      _editBooking(booking);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      side: BorderSide(color: Colors.blue[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Cancel Booking'),
                    onPressed: () {
                      Navigator.pop(context);
                      _showCancellationConfirmation(booking);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Filter Bookings',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('All Bookings', true),
            _buildFilterOption('Upcoming Bookings', false),
            _buildFilterOption('Current Stays', false),
            _buildFilterOption('Past Bookings', false),
            const Divider(),
            _buildFilterOption('Booking.com', false),
            _buildFilterOption('Airbnb', false),
            _buildFilterOption('Agoda', false),
            _buildFilterOption('Manual Entries', false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('APPLY'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(String label, bool isSelected) {
    return CheckboxListTile(
      title: Text(label),
      value: isSelected,
      onChanged: (value) {
        // In a real implementation, you would update filter state here
      },
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
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

  void _filterBookings(List<Booking> allBookings) {
    setState(() {
      _filteredBookings = _applyFilters(allBookings);
    });
  }

  void _updateBlackoutDates() {
    setState(() {
      _blackoutDates = _getBlackoutDates();
    });
  }

  List<Booking> _applyFilters(List<Booking> bookings) {
    // Start with all bookings
    List<Booking> filteredList = List.from(bookings);

    // Apply room filter first
    if (_selectedRoomFilter != null) {
      filteredList = filteredList.where((booking) => booking.roomId == _selectedRoomFilter).toList();
    }

    // Apply date range filter to room-filtered results
    if (_dateRangeFilter != null) {
      filteredList = filteredList.where((booking) {
        final checkInWithinRange = !booking.checkIn.isBefore(_dateRangeFilter!.start) && !booking.checkIn.isAfter(_dateRangeFilter!.end);

        final checkOutWithinRange = !booking.checkOut.isBefore(_dateRangeFilter!.start) && !booking.checkOut.isAfter(_dateRangeFilter!.end);

        final bookingSpansRange = booking.checkIn.isBefore(_dateRangeFilter!.start) && booking.checkOut.isAfter(_dateRangeFilter!.end);

        return checkInWithinRange || checkOutWithinRange || bookingSpansRange;
      }).toList();
    }

    // Apply search to date-filtered results
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredList = filteredList.where((booking) {
        // Search in booking ID
        if (booking.id.toLowerCase().contains(query)) {
          return true;
        }

        // Search in guest name
        if (booking.guestName.toLowerCase().contains(query)) {
          return true;
        }

        // Search in room name
        final roomName = _getRoomName(booking.roomId).toLowerCase();
        if (roomName.contains(query)) {
          return true;
        }

        // Search in dates
        if (booking.formattedCheckIn.toLowerCase().contains(query) || booking.formattedCheckOut.toLowerCase().contains(query)) {
          return true;
        }

        // Search in other fields
        if (booking.guestEmail != null && booking.guestEmail!.toLowerCase().contains(query)) {
          return true;
        }

        if (booking.guestPhone != null && booking.guestPhone!.toLowerCase().contains(query)) {
          return true;
        }

        if (booking.notes != null && booking.notes!.toLowerCase().contains(query)) {
          return true;
        }

        return false;
      }).toList();
    }

    return filteredList;
  }

  void _updateFilters() {
    setState(() {
      _isFilterActive = _selectedRoomFilter != null || _dateRangeFilter != null;
      // Re-apply all filters with the current search
      _filteredBookings = _applyFilters(_lastBookings);
    });
  }

  void _showFilterOptions() {
    // Store the current filter state to detect changes
    final previousRoomFilter = _selectedRoomFilter;
    final previousDateFilter = _dateRangeFilter;

    final currentBookings = _lastBookings;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Bookings',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.grey[800],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Room filter section
                Text(
                  'Filter by Room',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),

                // Room selection
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // "All Rooms" option
                    FilterChip(
                      label: const Text('All Rooms'),
                      selected: _selectedRoomFilter == null,
                      onSelected: (selected) {
                        if (selected) {
                          setModalState(() {
                            _selectedRoomFilter = null;
                          });
                        }
                      },
                      backgroundColor: Colors.grey[100],
                      selectedColor: Colors.blue[100],
                      checkmarkColor: Colors.blue[800],
                      labelStyle: TextStyle(
                        color: _selectedRoomFilter == null ? Colors.blue[800] : Colors.grey[800],
                        fontWeight: _selectedRoomFilter == null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),

                    // Individual room options
                    ..._rooms.map((room) {
                      return FilterChip(
                        label: Text(room['name']),
                        selected: _selectedRoomFilter == room['id'],
                        onSelected: (selected) {
                          setModalState(() {
                            _selectedRoomFilter = selected ? room['id'] : null;
                          });
                        },
                        backgroundColor: Colors.grey[100],
                        selectedColor: Colors.blue[100],
                        checkmarkColor: Colors.blue[800],
                        labelStyle: TextStyle(
                          color: _selectedRoomFilter == room['id'] ? Colors.blue[800] : Colors.grey[800],
                          fontWeight: _selectedRoomFilter == room['id'] ? FontWeight.w600 : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ],
                ),

                const SizedBox(height: 24),

                // Date range filter section
                Text(
                  'Filter by Date Range',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 16),

                // Date range selector
                InkWell(
                  onTap: () async {
                    final DateTimeRange? pickedRange = await showDateRangePicker(
                      context: context,
                      initialDateRange: _dateRangeFilter,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.blue[600]!,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: Colors.grey[800]!,
                            ),
                            dialogBackgroundColor: Colors.white,
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (pickedRange != null) {
                      setModalState(() {
                        _dateRangeFilter = pickedRange;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range, color: Colors.blue[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _dateRangeFilter == null
                              ? Text(
                                  'Select date range',
                                  style: TextStyle(color: Colors.grey[600]),
                                )
                              : Text(
                                  '${DateFormat('MMM dd, yyyy').format(_dateRangeFilter!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRangeFilter!.end)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[800],
                                  ),
                                ),
                        ),
                        if (_dateRangeFilter != null)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setModalState(() {
                                _dateRangeFilter = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedRoomFilter = null;
                            _dateRangeFilter = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Reset Filters'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isFilterActive = _selectedRoomFilter != null || _dateRangeFilter != null;
                            _filteredBookings = _applyFilters(_lastBookings);
                          });

                          // Close the modal
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      // Check if filters changed and apply if needed
      if (previousRoomFilter != _selectedRoomFilter || previousDateFilter != _dateRangeFilter) {
        _filterBookings(currentBookings);
      }
    });
  }

  Color _getAvailabilityColor() {
    final availableCount = _roomAvailability.values.where((available) => available).length;
    final totalCount = _roomAvailability.length;

    if (availableCount == 0) {
      return Colors.red[50]!;
    } else if (availableCount < totalCount / 2) {
      return Colors.orange[50]!;
    } else {
      return Colors.green[50]!;
    }
  }

  Color _getAvailabilityBorderColor() {
    final availableCount = _roomAvailability.values.where((available) => available).length;
    final totalCount = _roomAvailability.length;

    if (availableCount == 0) {
      return Colors.red[200]!;
    } else if (availableCount < totalCount / 2) {
      return Colors.orange[200]!;
    } else {
      return Colors.green[200]!;
    }
  }

  Color _getAvailabilityTextColor() {
    final availableCount = _roomAvailability.values.where((available) => available).length;
    final totalCount = _roomAvailability.length;

    if (availableCount == 0) {
      return Colors.red[700]!;
    } else if (availableCount < totalCount / 2) {
      return Colors.orange[700]!;
    } else {
      return Colors.green[700]!;
    }
  }

  bool get _hasActiveFilters => _selectedRoomFilter != null || _dateRangeFilter != null;
}

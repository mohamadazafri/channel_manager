import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../blocs/booking/booking_bloc.dart';
import '../../blocs/booking/booking_event.dart';
import '../../blocs/booking/booking_state.dart';
import '../../models/booking.dart';
import '../../models/enums/booking_source.dart';
import '../../models/room.dart';

class BookingFormScreen extends StatefulWidget {
  final Booking? booking;
  final String? initialRoom;
  final DateTimeRange? initialDates;

  const BookingFormScreen({
    Key? key,
    this.booking,
    this.initialRoom,
    this.initialDates,
  }) : super(key: key);

  @override
  _BookingFormScreenState createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedRoomId;
  DateTimeRange? _dateRange;
  bool _isConfirmed = true;

  bool get _isEditing => widget.booking != null;

  final List<Room> _rooms = [
    Room(id: 'room1', name: 'Deluxe Room 101', type: 'Deluxe', capacity: 2, price: 100),
    Room(id: 'room2', name: 'Standard Room 102', type: 'Standard', capacity: 2, price: 80),
    Room(id: 'room3', name: 'Suite 201', type: 'Suite', capacity: 4, price: 150),
    // This would usually come from a repository or service
  ];

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      // Populate form fields with existing booking data
      _nameController.text = widget.booking!.guestName;
      _emailController.text = widget.booking!.guestEmail ?? '';
      _phoneController.text = widget.booking!.guestPhone ?? '';
      _notesController.text = widget.booking!.notes ?? '';
      _selectedRoomId = widget.booking!.roomId;
      _dateRange = DateTimeRange(
        start: widget.booking!.checkIn,
        end: widget.booking!.checkOut,
      );
      _isConfirmed = widget.booking!.isConfirmed;
    } else {
      // Use initial values if provided
      _selectedRoomId = widget.initialRoom;
      _dateRange = widget.initialDates;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          _isEditing ? 'Edit Booking' : 'New Booking',
          style: const TextStyle(
            color: Color(0xFF2E4057),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2E4057)),
      ),
      body: BlocListener<BookingBloc, BookingState>(
        listener: (context, state) {
          if (state is BookingCreated || state is BookingUpdated) {
            // Navigate back on success
            Navigator.pop(context);

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isEditing ? 'Booking updated successfully' : 'Booking created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is BookingError) {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSection(
                  title: 'Guest Information',
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Guest Name',
                      icon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter guest name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty && !value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Booking Details',
                  children: [
                    _buildDropdown(),
                    const SizedBox(height: 16),
                    _buildDateRangePicker(),
                    const SizedBox(height: 16),
                    _buildConfirmationSwitch(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _notesController,
                      label: 'Notes',
                      icon: Icons.note,
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _validateAndSubmit,
                  style: ElevatedButton.styleFrom(
                    textStyle: TextStyle(color: Colors.blue[600]),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isEditing ? 'Update Booking' : 'Create Booking',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
    );
  }

  Widget _buildDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Select Room',
        prefixIcon: Icon(Icons.hotel, color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      value: _selectedRoomId,
      items: _rooms.map((room) {
        return DropdownMenuItem<String>(
          value: room.id,
          child: Text('${room.name} (${room.capacity} pax)'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedRoomId = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a room';
        }
        return null;
      },
    );
  }

  Widget _buildDateRangePicker() {
    return InkWell(
      onTap: _selectDateRange,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Check-in/Check-out Dates',
          prefixIcon: Icon(Icons.date_range, color: Colors.grey[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _dateRange != null
                  ? '${DateFormat('MMM dd, yyyy').format(_dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRange!.end)}'
                  : 'Select dates',
              style: TextStyle(
                color: _dateRange != null ? Colors.black87 : Colors.grey[600],
                fontSize: 16,
              ),
            ),
            if (_dateRange != null) ...[
              const SizedBox(height: 4),
              Text(
                'Duration: ${_dateRange!.duration.inDays} nights',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Confirmed',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
          ),
          Switch(
            value: _isConfirmed,
            onChanged: (value) {
              setState(() {
                _isConfirmed = value;
              });
            },
            activeColor: Colors.green[600],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final initialDateRange = _dateRange ??
        DateTimeRange(
          start: DateTime.now(),
          end: DateTime.now().add(const Duration(days: 3)),
        );

    // Get today's date at midnight
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Set the minimum date differently based on whether we're editing or creating
    final DateTime firstDate;

    if (_isEditing) {
      // If editing an existing booking, enforce that:
      // 1. You can't change a past booking to start in the future (keep original date)
      // 2. You can't move a future booking to start in the past
      // So we use the minimum of (original check-in date, today)
      final originalCheckIn = widget.booking!.checkIn;
      final originalCheckInDay = DateTime(originalCheckIn.year, originalCheckIn.month, originalCheckIn.day);

      if (originalCheckInDay.isBefore(today)) {
        // If the booking was in the past, keep the original date but show a message
        firstDate = originalCheckInDay;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notice: This booking has dates in the past'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        });
      } else {
        // For future bookings, you can't move them to the past
        firstDate = today;
      }
    } else {
      // For new bookings, never allow past dates
      firstDate = today;
    }

    final newDateRange = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialDateRange,
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

    if (newDateRange != null) {
      setState(() {
        _dateRange = newDateRange;
      });
    }
  }

  void _validateAndSubmit() {
    if (_formKey.currentState!.validate() && _dateRange != null) {
      // Get today's date at midnight for comparison
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Check if this is a new booking with dates in the past
      if (!_isEditing && _dateRange!.start.isBefore(today)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot create a booking starting in the past'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if this is an existing booking being moved to the past
      if (_isEditing) {
        final originalCheckIn = widget.booking!.checkIn;
        final originalCheckInDay = DateTime(originalCheckIn.year, originalCheckIn.month, originalCheckIn.day);

        // If original booking was in the future but now being moved to the past
        if (!originalCheckInDay.isBefore(today) && _dateRange!.start.isBefore(today)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot change a future booking to start in the past'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final booking = _createBookingFromForm();

      if (_isEditing) {
        context.read<BookingBloc>().add(UpdateBooking(booking));
      } else {
        // First check for overlaps
        context.read<BookingBloc>().add(CheckForOverlaps(booking));

        // Create the booking if no overlaps
        context.read<BookingBloc>().add(CreateBooking(booking));
      }
    } else if (_dateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select check-in and check-out dates'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Booking _createBookingFromForm() {
    final uuid = const Uuid();

    return Booking(
      id: _isEditing ? widget.booking!.id : uuid.v4(),
      guestName: _nameController.text,
      checkIn: _dateRange!.start,
      checkOut: _dateRange!.end,
      source: BookingSource.manual,
      roomId: _selectedRoomId!,
      isConfirmed: _isConfirmed,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      guestEmail: _emailController.text.isEmpty ? null : _emailController.text,
      guestPhone: _phoneController.text.isEmpty ? null : _phoneController.text,
    );
  }
}

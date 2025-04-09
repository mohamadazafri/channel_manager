import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homestay_booking/blocs/booking/booking_bloc.dart';
import 'package:homestay_booking/blocs/booking/booking_event.dart';
import 'package:homestay_booking/services/local/local_database_service.dart';
import '../../blocs/sync/sync_bloc.dart';
import '../../blocs/sync/sync_event.dart';
import '../../blocs/sync/sync_state.dart';
import '../../services/api/booking_dot_com_service.dart';
import '../../services/api/agoda_service.dart';
import '../../services/api/airbnb_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Sync interval options in minutes
  final List<int> _syncIntervals = [15, 30, 60, 120, 240];
  int _selectedSyncInterval = 60;

  // API connection status
  bool _bookingDotComConnected = false;
  bool _agodaConnected = false;
  bool _airbnbConnected = false;

  // API service instances
  late BookingDotComService _bookingDotComService;
  late AgodaService _agodaService;
  late AirbnbService _airbnbService;

  @override
  void initState() {
    super.initState();

    // These would be properly injected in a real app
    _bookingDotComService = context.read<BookingDotComService>();
    _agodaService = context.read<AgodaService>();
    _airbnbService = context.read<AirbnbService>();

    _checkConnectionStatus();
  }

  Future<void> _checkConnectionStatus() async {
    final bookingDotComConnected = await _bookingDotComService.isConnected();
    final agodaConnected = await _agodaService.isConnected();
    final airbnbConnected = await _airbnbService.isConnected();

    setState(() {
      _bookingDotComConnected = bookingDotComConnected;
      _agodaConnected = agodaConnected;
      _airbnbConnected = airbnbConnected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: BlocListener<SyncBloc, SyncState>(
        listener: (context, state) {
          if (state is SyncSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is SyncError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80.0),
          child: ListView(
            children: [
              _buildSectionHeader('Synchronization'),
              _buildSyncIntervalSelector(),
              _buildSyncButton(),
              _buildSectionHeader('API Connections'),
              _buildApiConnectionItem(
                'Booking.com',
                _bookingDotComConnected,
                _connectBookingDotCom,
                _disconnectBookingDotCom,
                Icons.hotel,
                Colors.blue,
              ),
              _buildApiConnectionItem(
                'Agoda',
                _agodaConnected,
                _connectAgoda,
                _disconnectAgoda,
                Icons.business,
                Colors.red,
              ),
              _buildApiConnectionItem(
                'Airbnb',
                _airbnbConnected,
                _connectAirbnb,
                _disconnectAirbnb,
                Icons.house,
                Colors.pink,
              ),
              _buildSectionHeader('App Settings'),
              SwitchListTile(
                title: const Text('Notifications'),
                subtitle: const Text('Get notified about new bookings'),
                value: true, // This would come from shared preferences
                onChanged: (value) {
                  // Would save to shared preferences
                },
              ),
              ListTile(
                title: const Text('Cache Management'),
                subtitle: const Text('Clear local booking data'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  _showCacheManagementOptions();
                },
              ),
              ListTile(
                title: const Text('About'),
                subtitle: const Text('Version 1.0.0'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Show about dialog
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildSyncIntervalSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Expanded(
            child: Text('Auto-sync interval'),
          ),
          DropdownButton<int>(
            value: _selectedSyncInterval,
            items: _syncIntervals.map((interval) {
              return DropdownMenuItem<int>(
                value: interval,
                child: Text('$interval min'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedSyncInterval = value;
                });

                // Schedule sync with the new interval
                context.read<SyncBloc>().add(
                      ScheduleSync(Duration(minutes: value)),
                    );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () {
          context.read<SyncBloc>().add(const StartSync());
        },
        icon: const Icon(Icons.sync),
        label: const Text('Sync Now'),
      ),
    );
  }

  Widget _buildApiConnectionItem(
    String name,
    bool isConnected,
    VoidCallback onConnect,
    VoidCallback onDisconnect,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(name),
      subtitle: Text(
        isConnected ? 'Connected' : 'Not connected',
        style: TextStyle(
          color: isConnected ? Colors.green : Colors.grey,
        ),
      ),
      trailing: isConnected
          ? ElevatedButton(
              onPressed: onDisconnect,
              style: ElevatedButton.styleFrom(
                // primary: Colors.red,
                backgroundColor: Colors.red,
              ),
              child: const Text('Disconnect'),
            )
          : ElevatedButton(
              onPressed: onConnect,
              child: const Text('Connect'),
            ),
    );
  }

  void _connectBookingDotCom() {
    _showApiCredentialsDialog(
      'Booking.com',
      [
        _buildCredentialField('Username'),
        _buildCredentialField('Password'),
      ],
      (credentials) async {
        // Call connect on the service
        final success = await _bookingDotComService.connect(credentials);

        if (success) {
          setState(() {
            _bookingDotComConnected = true;
          });
        }

        return success;
      },
    );
  }

  void _disconnectBookingDotCom() {
    // This would delete credentials
    setState(() {
      _bookingDotComConnected = false;
    });
  }

  void _connectAgoda() {
    _showApiCredentialsDialog(
      'Agoda',
      [
        _buildCredentialField('API Key'),
      ],
      (credentials) async {
        // Call connect on the service
        final success = await _agodaService.connect(credentials);

        if (success) {
          setState(() {
            _agodaConnected = true;
          });
        }

        return success;
      },
    );
  }

  void _disconnectAgoda() {
    setState(() {
      _agodaConnected = false;
    });
  }

  void _connectAirbnb() {
    _showApiCredentialsDialog(
      'Airbnb',
      [
        _buildCredentialField('Access Token'),
      ],
      (credentials) async {
        // Call connect on the service
        final success = await _airbnbService.connect(credentials);

        if (success) {
          setState(() {
            _airbnbConnected = true;
          });
        }

        return success;
      },
    );
  }

  void _disconnectAirbnb() {
    setState(() {
      _airbnbConnected = false;
    });
  }

  Widget _buildCredentialField(String label) {
    final controller = TextEditingController();
    final key = label.toLowerCase().replaceAll(' ', '_');

    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      obscureText: label.toLowerCase().contains('password') || label.toLowerCase().contains('token') || label.toLowerCase().contains('key'),
      onChanged: (value) {
        // Store value for submission
        _credentialValues[key] = value;
      },
    );
  }

  final Map<String, String> _credentialValues = {};

  void _showApiCredentialsDialog(
    String platform,
    List<Widget> fields,
    Future<bool> Function(Map<String, String>) onSubmit,
  ) {
    _credentialValues.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connect to $platform'),
        content: SingleChildScrollView(
          child: ListBody(
            children: fields,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await onSubmit(_credentialValues);

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'Successfully connected to $platform' : 'Failed to connect to $platform',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text('CONNECT'),
          ),
        ],
      ),
    );
  }

  void _showCacheManagementOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cache Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Option to clear only bookings
            ListTile(
              leading: Icon(Icons.cleaning_services, color: Colors.blue[700]),
              title: const Text('Clear Booking Cache'),
              subtitle: const Text('Removes all locally stored booking data'),
              onTap: () {
                Navigator.pop(context);
                _showClearConfirmation(
                  title: 'Clear Booking Cache',
                  message: 'This will remove all locally stored booking data. API connections will remain intact.',
                  onConfirm: _clearBookingsOnly,
                );
              },
            ),

            const Divider(),

            // Option to clear all data
            ListTile(
              leading: Icon(Icons.delete_sweep, color: Colors.red[700]),
              title: const Text('Clear All Data'),
              subtitle: const Text('Removes all bookings and room data'),
              onTap: () {
                Navigator.pop(context);
                _showClearConfirmation(
                  title: 'Clear All Data',
                  message: 'This will permanently delete all your bookings and room data. This action cannot be undone.',
                  onConfirm: _clearAllData,
                  isDestructive: true,
                );
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showClearConfirmation({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.red[800] : Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red[600] : Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: Text(isDestructive ? 'CLEAR ALL DATA' : 'CLEAR CACHE'),
          ),
        ],
      ),
    );
  }

  void _clearBookingsOnly() {
    _showLoadingDialog('Clearing booking cache...');

    final dbService = context.read<LocalDatabaseService>();
    dbService.clearBookingsOnly().then((_) {
      Navigator.pop(context); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking cache cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the bookings
      context.read<BookingBloc>().add(const FetchBookings());
    }).catchError((error) {
      Navigator.pop(context); // Close loading dialog

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear cache: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _clearAllData() {
    _showLoadingDialog('Clearing all data...');

    final dbService = context.read<LocalDatabaseService>();
    dbService.clearAllData().then((_) {
      Navigator.pop(context); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the bookings
      context.read<BookingBloc>().add(const FetchBookings());
    }).catchError((error) {
      Navigator.pop(context); // Close loading dialog

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear data: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text(message),
              ],
            ),
          ),
        );
      },
    );
  }
}

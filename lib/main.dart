import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:homestay_booking/ui/widgets/floating_bottom_nav.dart';
import 'services/api/booking_dot_com_service.dart';
import 'services/api/agoda_service.dart';
import 'services/api/airbnb_service.dart';
import 'services/local/local_database_service.dart';
import 'services/utils/api_credential_service.dart';
import 'repositories/booking_repository.dart';
import 'blocs/booking/booking_bloc.dart';
import 'blocs/sync/sync_bloc.dart';
import 'blocs/sync/sync_event.dart';
import 'ui/screens/booking_calendar_screen.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database
  final dbService = LocalDatabaseService();
  await dbService.database;

  runApp(MyApp(dbService: dbService));
}

class MyApp extends StatelessWidget {
  final LocalDatabaseService dbService;

  const MyApp({Key? key, required this.dbService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Homestay Booking',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: MultiBlocProvider(
        providers: [
          // Services
          RepositoryProvider<ApiCredentialService>(
            create: (_) => ApiCredentialService(),
          ),
          RepositoryProvider<BookingDotComService>(
            create: (context) => BookingDotComService(
              'https://api.booking.com',
              context.read<ApiCredentialService>(),
            ),
          ),
          RepositoryProvider<AgodaService>(
            create: (context) => AgodaService(
              'https://api.agoda.com',
              context.read<ApiCredentialService>(),
            ),
          ),
          RepositoryProvider<AirbnbService>(
            create: (context) => AirbnbService(
              'https://api.airbnb.com',
              context.read<ApiCredentialService>(),
            ),
          ),
          RepositoryProvider<LocalDatabaseService>(
            create: (_) => dbService,
          ),

          // Repository
          RepositoryProvider<BookingRepository>(
            create: (context) => BookingRepository(
              context.read<BookingDotComService>(),
              context.read<AgodaService>(),
              context.read<AirbnbService>(),
              context.read<LocalDatabaseService>(),
            ),
          ),

          // BLoCs
          BlocProvider<BookingBloc>(
            create: (context) => BookingBloc(
              repository: context.read<BookingRepository>(),
            ),
          ),
          BlocProvider<SyncBloc>(
            create: (context) => SyncBloc(
              repository: context.read<BookingRepository>(),
            )..add(const ScheduleSync(Duration(minutes: 60))),
          ),
        ],
        child: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const BookingCalendarScreen(),
    const DashboardScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      extendBody: true, // Important to allow content to extend behind the navigation bar
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: FloatingBottomNavigation(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'booking_api_service.dart';
import '../../models/booking.dart';
import '../../models/enums/booking_source.dart';
import '../utils/api_credential_service.dart';

/// Implementation of BookingApiService for the Airbnb API.
class AirbnbService implements BookingApiService {
  final String baseUrl;
  final ApiCredentialService _credentialService;

  /// Creates a new AirbnbService.
  ///
  /// [baseUrl] The base URL for the Airbnb API.
  /// [credentialService] Service for managing API credentials.
  AirbnbService(this.baseUrl, this._credentialService);

  @override
  Future<List<Booking>> fetchBookings({DateTime? from, DateTime? to}) async {
    final credentials = await _credentialService.getCredentials('airbnb');
    if (credentials == null) {
      throw Exception('Airbnb credentials not found');
    }

    final fromDate = from ?? DateTime.now();
    final toDate = to ?? DateTime.now().add(const Duration(days: 90));

    final uri = Uri.parse('$baseUrl/v2/reservations').replace(queryParameters: {
      'check_in_start_date': fromDate.toIso8601String().split('T')[0],
      'check_in_end_date': toDate.toIso8601String().split('T')[0],
    });

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer ${credentials['accessToken']}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> bookingsJson = responseData['reservations'] ?? [];

      return bookingsJson.map((json) {
        // Transform Airbnb's response format to match our Booking model
        return Booking.fromJson({
          'id': json['confirmation_code'],
          'guest_name': json['guest']['first_name'] + ' ' + json['guest']['last_name'],
          'check_in': json['start_date'],
          'check_out': json['end_date'],
          'source': 'airbnb',
          'room_id': json['listing_id'],
          'is_confirmed': json['status'] == 'accepted',
          'guest_email': json['guest']['email'],
          'guest_phone': json['guest']['phone'],
          'notes': json['guest_note'],
        });
      }).toList();
    } else {
      throw Exception('Failed to fetch Airbnb bookings: ${response.body}');
    }
  }

  @override
  Future<Booking> createBooking(Booking booking) async {
    // This method might not be needed if bookings are only created on Airbnb's platform
    throw UnimplementedError('Creating bookings via Airbnb API is not supported');
  }

  @override
  Future<Booking> updateBooking(Booking booking) async {
    final credentials = await _credentialService.getCredentials('airbnb');
    if (credentials == null) {
      throw Exception('Airbnb credentials not found');
    }

    final uri = Uri.parse('$baseUrl/v2/reservations/${booking.id}');

    // Transform our Booking model to match Airbnb's expected format
    final Map<String, dynamic> airbnbBookingData = {
      'status': booking.isConfirmed ? 'accepted' : 'pending',
      'guest_note': booking.notes,
    };

    final response = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer ${credentials['accessToken']}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(airbnbBookingData),
    );

    if (response.statusCode == 200) {
      // Return the updated booking (might need to adapt based on Airbnb's response)
      return booking;
    } else {
      throw Exception('Failed to update Airbnb booking: ${response.body}');
    }
  }

  @override
  Future<bool> cancelBooking(String bookingId) async {
    final credentials = await _credentialService.getCredentials('airbnb');
    if (credentials == null) {
      throw Exception('Airbnb credentials not found');
    }

    final uri = Uri.parse('$baseUrl/v2/reservations/$bookingId/cancel');

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer ${credentials['accessToken']}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'reason': 'host_canceled',
      }),
    );

    return response.statusCode == 200;
  }

  @override
  Future<bool> connect(Map<String, String> credentials) async {
    try {
      // Test the credentials by making a simple API call
      final uri = Uri.parse('$baseUrl/v2/listings');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${credentials['accessToken']}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Save credentials if connection is successful
        await _credentialService.saveCredentials('airbnb', credentials);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> isConnected() async {
    return await _credentialService.hasCredentials('airbnb');
  }
}

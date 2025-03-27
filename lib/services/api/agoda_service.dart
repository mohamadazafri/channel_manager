import 'dart:convert';
import 'package:http/http.dart' as http;
import 'booking_api_service.dart';
import '../../models/booking.dart';
import '../../models/enums/booking_source.dart';
import '../utils/api_credential_service.dart';

/// Implementation of BookingApiService for the Agoda API.
class AgodaService implements BookingApiService {
  final String baseUrl;
  final ApiCredentialService _credentialService;
  
  /// Creates a new AgodaService.
  /// 
  /// [baseUrl] The base URL for the Agoda API.
  /// [credentialService] Service for managing API credentials.
  AgodaService(this.baseUrl, this._credentialService);
  
  @override
  Future<List<Booking>> fetchBookings({DateTime? from, DateTime? to}) async {
    final credentials = await _credentialService.getCredentials('agoda');
    if (credentials == null) {
      throw Exception('Agoda credentials not found');
    }
    
    final fromDate = from ?? DateTime.now();
    final toDate = to ?? DateTime.now().add(const Duration(days: 90));
    
    final uri = Uri.parse('$baseUrl/v1/bookings')
      .replace(queryParameters: {
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
      });
    
    final response = await http.get(
      uri,
      headers: {
        'X-API-Key': credentials['apiKey'] ?? '',
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final List<dynamic> bookingsJson = responseData['bookings'] ?? [];
      
      return bookingsJson.map((json) {
        // Transform Agoda's response format to match our Booking model
        return Booking.fromJson({
          'id': json['bookingId'],
          'guest_name': '${json['guestFirstName']} ${json['guestLastName']}',
          'check_in': json['checkInDate'],
          'check_out': json['checkOutDate'],
          'source': 'agoda',
          'room_id': json['roomId'],
          'is_confirmed': json['status'] == 'confirmed',
          'guest_email': json['guestEmail'],
          'guest_phone': json['guestPhone'],
          'notes': json['specialRequests'],
        });
      }).toList();
    } else {
      throw Exception('Failed to fetch Agoda bookings: ${response.body}');
    }
  }
  
  @override
  Future<Booking> createBooking(Booking booking) async {
    // This method might not be needed if bookings are only created on Agoda's platform
    throw UnimplementedError('Creating bookings via Agoda API is not supported');
  }
  
  @override
  Future<Booking> updateBooking(Booking booking) async {
    final credentials = await _credentialService.getCredentials('agoda');
    if (credentials == null) {
      throw Exception('Agoda credentials not found');
    }
    
    final uri = Uri.parse('$baseUrl/v1/bookings/${booking.id}');
    
    // Transform our Booking model to match Agoda's expected format
    final Map<String, dynamic> agodaBookingData = {
      'bookingId': booking.id,
      'checkInDate': booking.checkIn.toIso8601String(),
      'checkOutDate': booking.checkOut.toIso8601String(),
      'roomId': booking.roomId,
      'status': booking.isConfirmed ? 'confirmed' : 'pending',
      'specialRequests': booking.notes,
    };
    
    final response = await http.put(
      uri,
      headers: {
        'X-API-Key': credentials['apiKey'] ?? '',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(agodaBookingData),
    );
    
    if (response.statusCode == 200) {
      // Return the updated booking (might need to adapt based on Agoda's response)
      return booking;
    } else {
      throw Exception('Failed to update Agoda booking: ${response.body}');
    }
  }
  
  @override
  Future<bool> cancelBooking(String bookingId) async {
    final credentials = await _credentialService.getCredentials('agoda');
    if (credentials == null) {
      throw Exception('Agoda credentials not found');
    }
    
    final uri = Uri.parse('$baseUrl/v1/bookings/$bookingId/cancel');
    
    final response = await http.post(
      uri,
      headers: {
        'X-API-Key': credentials['apiKey'] ?? '',
        'Content-Type': 'application/json',
      },
    );
    
    return response.statusCode == 200;
  }

  @override
  Future<bool> connect(Map<String, String> credentials) async {
    try {
      // Test the credentials by making a simple API call
      final uri = Uri.parse('$baseUrl/v1/properties');
      
      final response = await http.get(
        uri,
        headers: {
          'X-API-Key': credentials['apiKey'] ?? '',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        // Save credentials if connection is successful
        await _credentialService.saveCredentials('agoda', credentials);
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
    return await _credentialService.hasCredentials('agoda');
  }
}

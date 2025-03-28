import 'dart:convert';
import 'package:http/http.dart' as http;
import 'booking_api_service.dart';
import '../../models/booking.dart';
import '../../models/enums/booking_source.dart';
import '../utils/api_credential_service.dart';

/// Implementation of BookingApiService for the Booking.com API.
class BookingDotComService implements BookingApiService {
  final String baseUrl;
  final ApiCredentialService _credentialService;
  
  /// Creates a new BookingDotComService.
  /// 
  /// [baseUrl] The base URL for the Booking.com API.
  /// [credentialService] Service for managing API credentials.
  BookingDotComService(this.baseUrl, this._credentialService);
  
  @override
  Future<List<Booking>> fetchBookings({DateTime? from, DateTime? to}) async {
    final credentials = await _credentialService.getCredentials('booking.com');
    if (credentials == null) {
      throw Exception('Booking.com credentials not found');
    }
    
    final fromDate = from ?? DateTime.now();
    final toDate = to ?? DateTime.now().add(const Duration(days: 90));
    
    final uri = Uri.parse('$baseUrl/bookings')
      .replace(queryParameters: {
        'from_date': fromDate.toIso8601String(),
        'to_date': toDate.toIso8601String(),
      });
    
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('${credentials['username']}:${credentials['password']}'))}',
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> bookingsJson = jsonDecode(response.body);
      
      return bookingsJson.map((json) {
        // Map Booking.com response to our Booking model
        // This mapping might need adjustment based on actual API response
        return Booking.fromJson({
          'id': json['id'],
          'guest_name': '${json['guest_first_name']} ${json['guest_last_name']}',
          'check_in': json['arrival_date'],
          'check_out': json['departure_date'],
          'source': 'booking.com',
          'room_id': json['room_id'],
          'is_confirmed': json['status'] == 'confirmed',
          'guest_email': json['guest_email'],
          'guest_phone': json['guest_phone'],
          'notes': json['remarks'],
        });
      }).toList();
    } else {
      throw Exception('Failed to fetch Booking.com bookings: ${response.body}');
    }
  }
  
  @override
  Future<Booking> createBooking(Booking booking) async {
    // This method might not be needed if bookings are only created on Booking.com's platform
    throw UnimplementedError('Creating bookings via Booking.com API is not supported');
  }
  
  @override
  Future<Booking> updateBooking(Booking booking) async {
    final credentials = await _credentialService.getCredentials('booking.com');
    if (credentials == null) {
      throw Exception('Booking.com credentials not found');
    }
    
    final uri = Uri.parse('$baseUrl/bookings/${booking.id}');
    
    // Transform our Booking model to match Booking.com's expected format
    final Map<String, dynamic> bookingDotComData = {
      'status': booking.isConfirmed ? 'confirmed' : 'pending',
      'remarks': booking.notes,
    };
    
    final response = await http.put(
      uri,
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('${credentials['username']}:${credentials['password']}'))}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(bookingDotComData),
    );
    
    if (response.statusCode == 200) {
      // Return the updated booking (might need to adapt based on Booking.com's response)
      return booking;
    } else {
      throw Exception('Failed to update Booking.com booking: ${response.body}');
    }
  }
  
  @override
  Future<bool> cancelBooking(String bookingId) async {
    final credentials = await _credentialService.getCredentials('booking.com');
    if (credentials == null) {
      throw Exception('Booking.com credentials not found');
    }
    
    final uri = Uri.parse('$baseUrl/bookings/$bookingId/cancel');
    
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('${credentials['username']}:${credentials['password']}'))}',
        'Content-Type': 'application/json',
      },
    );
    
    return response.statusCode == 200;
  }

  @override
  Future<bool> connect(Map<String, String> credentials) async {
    try {
      // Test the credentials by making a simple API call
      final uri = Uri.parse('$baseUrl/properties');
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${credentials['username']}:${credentials['password']}'))}',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        // Save credentials if connection is successful
        await _credentialService.saveCredentials('booking.com', credentials);
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
    return await _credentialService.hasCredentials('booking.com');
  }
}

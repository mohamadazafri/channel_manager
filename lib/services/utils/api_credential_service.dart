import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing and retrieving API credentials.
class ApiCredentialService {
  final FlutterSecureStorage _storage;
  
  /// Creates a new ApiCredentialService with the provided storage implementation.
  /// If no storage is provided, uses the default FlutterSecureStorage.
  ApiCredentialService({FlutterSecureStorage? storage}) 
    : _storage = storage ?? const FlutterSecureStorage();
  
  /// Saves API credentials for a specific platform.
  /// 
  /// [platform] The name of the platform (e.g., 'booking.com', 'agoda', 'airbnb').
  /// [credentials] Map containing the credentials to save.
  Future<void> saveCredentials(String platform, Map<String, String> credentials) async {
    await _storage.write(
      key: '${platform.toLowerCase()}_credentials', 
      value: jsonEncode(credentials)
    );
  }
  
  /// Gets API credentials for a specific platform.
  /// 
  /// [platform] The name of the platform.
  /// 
  /// Returns a Map containing the credentials, or null if not found.
  Future<Map<String, String>?> getCredentials(String platform) async {
    final credentialsJson = await _storage.read(key: '${platform.toLowerCase()}_credentials');
    if (credentialsJson == null) return null;
    
    try {
      final Map<String, dynamic> decoded = jsonDecode(credentialsJson);
      return Map<String, String>.from(decoded);
    } catch (e) {
      // Handle invalid JSON
      return null;
    }
  }
  
  /// Deletes API credentials for a specific platform.
  /// 
  /// [platform] The name of the platform.
  Future<void> deleteCredentials(String platform) async {
    await _storage.delete(key: '${platform.toLowerCase()}_credentials');
  }
  
  /// Checks if credentials exist for a specific platform.
  /// 
  /// [platform] The name of the platform.
  /// 
  /// Returns true if credentials exist, false otherwise.
  Future<bool> hasCredentials(String platform) async {
    final credentials = await getCredentials(platform);
    return credentials != null;
  }
  
  /// Lists all platforms that have stored credentials.
  /// 
  /// Returns a list of platform names.
  Future<List<String>> listPlatformsWithCredentials() async {
    final allKeys = await _storage.readAll();
    
    return allKeys.keys
      .where((key) => key.endsWith('_credentials'))
      .map((key) => key.replaceAll('_credentials', ''))
      .toList();
  }
}

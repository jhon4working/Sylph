import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'dart:async' show TimeoutException;
import 'dart:io';

// Check if device has internet connection
Future<bool> hasInternetConnection() async {
  try {
    final connectivityResult = await Connectivity().checkConnectivity();
    
    // If connected, try actual network request to verify
    if (connectivityResult != ConnectivityResult.none) {
      try {
        final result = await InternetAddress.lookup('8.8.8.8')
            .timeout(const Duration(seconds: 5));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        // DNS failed, but might still have connection
        return true;
      }
    }
    return false;
  } catch (e) {
    print('Connectivity check error: $e');
    return false;
  }
}

Future<Map<String, dynamic>> fetchWeather(String city, String owmKey) async {
  // Validate API key
  if (owmKey.isEmpty) {
    throw Exception('API key not set. Build with: flutter run --dart-define=OWM_KEY=your_key');
  }

  // Check internet connectivity first
  if (!await hasInternetConnection()) {
    throw Exception('No internet connection. Please check your network and try again.');
  }

  final url = Uri.parse(
    'https://api.openweathermap.org/data/2.5/weather?q=${Uri.encodeComponent(city)}&appid=$owmKey&units=metric',
  );

  int retries = 3;
  Exception? lastError;

  while (retries > 0) {
    try {
      final res = await http.get(url)
          .timeout(const Duration(seconds: 15))
          .catchError((error) {
        throw Exception('Network request failed: $error');
      });

      if (res.statusCode == 404) {
        throw Exception('City "$city" not found. Check spelling and try again.');
      } else if (res.statusCode == 401) {
        throw Exception('Invalid API key. Check your OWM_KEY.');
      } else if (res.statusCode != 200) {
        throw Exception('Server error (${res.statusCode}). Try again later.');
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return decoded;
    } on http.ClientException catch (e) {
      lastError = Exception('Network error: ${e.message}. Check your internet connection.');
      retries--;
      if (retries > 0) {
        await Future.delayed(const Duration(seconds: 2));
      }
    } on TimeoutException {
      lastError = Exception('Request timed out. Please check your connection and try again.');
      retries--;
      if (retries > 0) {
        await Future.delayed(const Duration(seconds: 2));
      }
    } on SocketException catch (e) {
      lastError = Exception('Connection failed: ${e.message}. Check your internet.');
      retries--;
      if (retries > 0) {
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      lastError = Exception('Error: ${e.toString()}');
      retries--;
      if (retries > 0) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  throw lastError ?? Exception('Failed to fetch weather after multiple attempts.');
}

Future<Map<String, dynamic>?> fetchAQI(String city, String waqiKey) async {
  // Validate API key
  if (waqiKey.isEmpty) {
    print('WAQI_KEY not set, skipping AQI');
    return null;
  }

  // Check internet connectivity first
  if (!await hasInternetConnection()) {
    return null;
  }

  final url = Uri.parse(
    'https://api.waqi.info/feed/${Uri.encodeComponent(city)}/?token=$waqiKey',
  );

  int retries = 2;

  while (retries > 0) {
    try {
      final res = await http.get(url)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        retries--;
        if (retries > 0) {
          await Future.delayed(const Duration(seconds: 2));
        }
        continue;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      
      // Check if response is successful
      if (data['status'] != 'ok') {
        return null;
      }

      // Return the data object directly (not wrapped in 'data' again)
      final aqiData = data['data'] as Map<String, dynamic>;
      return aqiData;
    } catch (e) {
      print('AQI fetch error: $e');
      retries--;
      if (retries > 0) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }
  return null;
}

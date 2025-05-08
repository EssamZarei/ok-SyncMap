import 'dart:io';
import 'dart:async'; // Add this import for TimeoutException
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class ApiService {
  // Base URL configuration
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000'; // For Flutter Web
    } else if (Platform.isWindows) {
      return 'http://localhost:5000'; // For Windows Desktop
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000'; // Android emulator
    } else {
      return 'http://localhost:5000'; // iOS and others
    }
  }

  // Text to speech with enhanced error handling
  static Future<File?> textToSpeech(String text,
    {String engine = 'gtts',
    String language = 'en',
    bool slow = false}) async {
    try {
      print('[TTS] Calling endpoint: $baseUrl/speak');
      print('[TTS] Sending text: "$text"');

      final response = await http.post(
        Uri.parse('$baseUrl/speak'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'text': text,
          'engine': engine,
          'language': language,
          'slow': slow.toString(),
        },
      ).timeout(const Duration(seconds: 50));

      print('[TTS] Response status: ${response.statusCode}');
      print('[TTS] Response headers: ${response.headers}');
      print('[TTS] Response body (first 100 chars): ${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}');

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final audioFile = File(
          '${dir.path}/speech_${DateTime.now().millisecondsSinceEpoch}.mp3',
        );
        await audioFile.writeAsBytes(response.bodyBytes);
        print('[TTS] Audio file saved to: ${audioFile.path}');
        return audioFile;
      } else {
        print('[TTS] Server error: ${response.statusCode}');
        return null;
      }
    } on SocketException catch (e) {
      print('[TTS] Network error: $e');
      return null;
    } on http.ClientException catch (e) {
      print('[TTS] HTTP client error: $e');
      return null;
    } on TimeoutException catch (e) {
      print('[TTS] Request timeout: $e');
      return null;
    } catch (e) {
      print('[TTS] Unexpected error: $e');
      return null;
    }
  }

  // Enhanced image upload with progress tracking
  static Future<String?> uploadImage(File image) async {
    try {
      print('[Upload] Starting upload for ${image.path}');
      
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'))
        ..files.add(await http.MultipartFile.fromPath(
          'image',
          image.path,
          filename: basename(image.path),
        ));

      final response = await request.send();
      final responseString = await response.stream.bytesToString();

      print('[Upload] Upload completed. Status: ${response.statusCode}');
      print('[Upload] Response: $responseString');

      if (response.statusCode == 200) {
        return responseString;
      }
      return null;
    } catch (e) {
      print('[Upload] Error uploading image: $e');
      return null;
    }
  }

  // Health check endpoint
  static Future<bool> checkServerStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 50));
      return response.statusCode == 200;
    } on TimeoutException catch (e) {
      print('[HealthCheck] Timeout: $e');
      return false;
    } catch (e) {
      print('[HealthCheck] Error: $e');
      return false;
    }
  }
}
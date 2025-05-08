import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

class ImageUploadService {
  static const String _serverUrl = 'http://192.168.236.1:5000/upload';
  // static const String _serverUrl = 'http://192.168.1.14:5000/upload';
  //static const String _serverUrl = 'http://10.24.121.70:5000/upload';

  static Future<String?> uploadImage(File imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(_serverUrl));
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          filename: basename(imageFile.path),
        ),
      );

      var response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return responseData; // Returns the path from server
      }
      return null;
    } on SocketException {
      print("Network error - please check your internet connection!");
    } on OutOfMemoryError {
      print("Critical error: Device memory full!");
    }catch (e) {
      print('Upload error: $e');
      return null;
    }
  }
}

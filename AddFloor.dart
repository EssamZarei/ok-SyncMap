import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myfirst/EditFloor.dart';
import '../DBConnection.dart';
import '../Login.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

class AddFloorWidget extends StatefulWidget {
  const AddFloorWidget({super.key});

  @override
  State<AddFloorWidget> createState() => _AddFloorWidgetState();
}

class _AddFloorWidgetState extends State<AddFloorWidget> {
  final TextEditingController _mapIdController = TextEditingController();
  final TextEditingController _floorNameController = TextEditingController();
  File? _selectedImage;
  String _message = '';
  bool _isLoading = false;
  bool _removeText = false; // New checkbox state

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _processImage() async {
    if (_selectedImage == null) return null;

    // Only process if remove text is checked
    if (!_removeText) return _selectedImage!.path;

    const serverUrl = 'http://localhost:5000/remove-text';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(serverUrl));
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        _selectedImage!.path,
        filename: basename(_selectedImage!.path),
      ));
      
      // Add required parameters for text removal
      request.fields['languages'] = 'en';
      request.fields['inpaint_radius'] = '3';

      var response = await request.send();
      
      if (response.statusCode == 200) {
        // Save processed image locally
        final bytes = await response.stream.toBytes();
        final String localPath = '${_selectedImage!.path}_processed.jpg';
        await File(localPath).writeAsBytes(bytes);
        return localPath;
      }
      return null;
    } catch (e) {
      print('Processing error: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    final userId = Login.getCurrentUserId();
    if (userId == null) {
      setState(() => _message = 'User ID not found. Please log in again.');
      return;
    }

    final mapId = int.tryParse(_mapIdController.text.trim());
    final floorName = _floorNameController.text.trim();

    if (mapId == null || floorName.isEmpty) {
      setState(() => _message = 'Please fill all fields.');
      return;
    }

    if (_selectedImage == null) {
      setState(() => _message = 'Please select an image');
      return;
    }

    final isAdmin = await DBConnection.isUserAdmin(userId);
    final isOwner = await DBConnection.isUserMapOwner(userId, mapId);

    if (!(isAdmin || isOwner)) {
      setState(() =>
          _message = 'You do not have permission to add a floor to this map.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Process image (text removal if checkbox is checked)
      final imagePath = await _processImage();
      if (imagePath == null) throw Exception('Image processing failed');

      // Then add floor with processed image path
      final isFloorAdded =
          await DBConnection.addFloor(mapId, floorName, imagePath);

      setState(() {
        _message =
            isFloorAdded ? 'Floor added successfully!' : 'Failed to add floor';
      });
    } on SocketException {
      print("Network error - please check your internet connection!");
    } on OutOfMemoryError {
      print("Critical error: Device memory full!");
    }catch (e) {
      setState(() => _message = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Floor')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            
            TextField(
              controller: _mapIdController,
              decoration: const InputDecoration(
                labelText: 'Map ID',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _floorNameController,
              decoration: const InputDecoration(
                labelText: 'Floor Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickImage,
              child: Text(_selectedImage == null
                  ? 'Select Floor Image'
                  : 'Image Selected'),
            ),
            if (_selectedImage != null)
              Image.file(_selectedImage!, height: 100),
            const SizedBox(height: 16),
            // Add the checkbox here
            CheckboxListTile(
              title: const Text('Remove text from image'),
              value: _removeText,
              onChanged: (bool? value) {
                setState(() {
                  _removeText = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submitForm,
                    child: const Text('Add Floor'),
                  ),
            const SizedBox(height: 20),
            Text(
              _message,
              style: TextStyle(
                color: _message.contains('successfully')
                    ? Colors.blue
                    : Colors.red,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => EditFloorNameWidget()),
                );
              },
              child: const Text('Edit Floor'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              child: const Text('Log In'),
            ),
            
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapIdController.dispose();
    _floorNameController.dispose();
    super.dispose();
  }
}

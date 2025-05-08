import 'dart:io';
import 'package:flutter/material.dart';
import '../DBConnection.dart';
import '../Login.dart';

class EditMapInfo extends StatefulWidget {
  const EditMapInfo({super.key});

  @override
  State<EditMapInfo> createState() => _EditMapInfoState();
}

class _EditMapInfoState extends State<EditMapInfo> {
  final TextEditingController _mapIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _message = ''; 
  bool _isLoading = false; 

  
  Future<void> _submitChanges() async {
    final userId = Login.getCurrentUserId(); 
    if (userId == null) {
      setState(() {
        _message = 'User ID not found. Please log in again.';
      });
      return;
    }

    
    final mapId = int.tryParse(_mapIdController.text.trim());
    if (mapId == null) {
      setState(() {
        _message = 'Invalid Map ID. Please enter a valid number.';
      });
      return;
    }

    // Check if the user is an admin or the owner of the map
    final isAdmin = await DBConnection.isUserAdmin(userId);
    final isOwner = await DBConnection.isUserMapOwner(userId, mapId);

    if (!(isAdmin || isOwner)) {
      setState(() {
        _message = 'You do not have permission to edit this map :(';
      });
      return;
    }

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      bool success = true;

      // Update map name if the field is not empty
      if (_nameController.text.isNotEmpty) {
        final result = await DBConnection.updateMapName(
          mapId,
          _nameController.text.trim(),
        );
        if (!result) success = false;
      }

      // Update map city if the field is not empty
      if (_cityController.text.isNotEmpty) {
        final result = await DBConnection.updateMapCity(
          mapId,
          _cityController.text.trim(),
        );
        if (!result) success = false;
      }

      // Update map type if the field is not empty
      if (_typeController.text.isNotEmpty) {
        final result = await DBConnection.updateMapType(
          mapId,
          _typeController.text.trim(),
        );
        if (!result) success = false;
      }

      // Update map location URL if the field is not empty
      if (_locationController.text.isNotEmpty) {
        final result = await DBConnection.updateMapLocationURL(
          mapId,
          _locationController.text.trim(),
        );
        if (!result) success = false;
      }

      // Display success or failure message
      setState(() {
        _message = success
            ? 'Map information updated successfully!'
            : 'Failed to update some fields, Please try again, This May Happen if Old Value = New Value';
        _isLoading = false; // Hide loading indicator
      });
    } on SocketException {
      print("Network error - please check your internet connection!");
    } on OutOfMemoryError {
      print("Critical error: Device memory full!");
    }catch (e) {
      print('Error: $e');
      setState(() {
        _message = 'An error occurred. Please try again later.';
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Map'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'New Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'New City',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _typeController,
              decoration: const InputDecoration(
                labelText: 'New Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'New Location URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator() // Show loading indicator
                : ElevatedButton(
                    onPressed: _submitChanges,
                    child: const Text('Submit Changes'),
                  ),
            const SizedBox(height: 16),
            Text(
              _message,
              style: TextStyle(
                color: _message.contains('successfully')
                    ? Colors.blue
                    : Colors.red,
              ),
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
    _nameController.dispose();
    _cityController.dispose();
    _typeController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}

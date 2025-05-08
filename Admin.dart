import 'package:flutter/material.dart';
import '../DBConnection.dart';
import '../Login.dart';

class AdminManagementWidget extends StatefulWidget {
  const AdminManagementWidget({super.key});

  @override
  State<AdminManagementWidget> createState() => _AdminManagementWidgetState();
}

class _AdminManagementWidgetState extends State<AdminManagementWidget> {
  // Controllers for deletion operations
  final _deleteMapController = TextEditingController();

  final _deleteWithMapController =
      TextEditingController(); // Required when deleting Floor or POI
  final _floorIdController = TextEditingController();
  final _poiIdController = TextEditingController();

  // Controllers for user management
  final _deleteUserController = TextEditingController();
  final _revokeAdminController = TextEditingController();
  final _grantAdminController = TextEditingController();

  final currentUserId = Login.getCurrentUserId();
  final bool _isSuperAdmin = Login.getCurrentUserId() == 1;

  String _message = '';
  bool _isLoading = false;

  bool? _isAdmin;
  bool? isOwner;

  Future<Map<String, bool>> _checkPermissions(int? mapId) async {
    if (currentUserId == null) throw Exception('Not logged in');

    _isAdmin ??= await DBConnection.isUserAdmin(currentUserId!);
    isOwner = await DBConnection.isUserMapOwner(currentUserId!, mapId!);

    return {
      'isSuperAdmin': _isSuperAdmin,
      'isAdmin': _isAdmin!,
      'isOwner': isOwner!,
    };
  }

  Future<void> _submitForm() async {
    setState(() {
      _message = '';
      _isLoading = true;
    });

    try {
      final accessMap = await _checkPermissions(
          _deleteMapController.text.isNotEmpty
              ? int.tryParse(_deleteMapController.text)
              : null);

      final accessFloorPOI = await _checkPermissions(
          _deleteWithMapController.text.isNotEmpty
              ? int.tryParse(_deleteWithMapController.text)
              : null);

      // Process all requested operations
      final operations = <Future>[];

      // Map deletion
      if (_deleteMapController.text.isNotEmpty) {
        final mapId = int.tryParse(_deleteMapController.text);
        if (mapId == null) throw Exception('Invalid Map ID');
        if (!(accessMap['isOwner']! || _isSuperAdmin))
          throw Exception('You dont own this map');
        operations.add(DBConnection.deleteMap(mapId));
      }

      // Floor deletion
      if (_floorIdController.text.isNotEmpty &&
          _deleteWithMapController.text.isNotEmpty) {
        final floorId = int.tryParse(_floorIdController.text);
        final mapId = int.tryParse(_deleteWithMapController.text);

        if (floorId == null || mapId == null) {
          throw Exception('Invalid Floor ID or Map ID');
        }

        if (!(accessFloorPOI['isOwner']! ||
            accessFloorPOI['isAdmin']! ||
            _isSuperAdmin)) {
          throw Exception('You dont have access to delete');
        }
        operations.add(DBConnection.deleteFloor(floorId, mapId));
      }

      // POI deletion
      if (_poiIdController.text.isNotEmpty &&
          _deleteWithMapController.text.isNotEmpty) {
        final poiId = int.tryParse(_poiIdController.text);
        final mapId = int.tryParse(_deleteWithMapController.text);

        if (poiId == null || mapId == null) {
          throw Exception('Invalid POI ID or Map ID');
        }
        if (!(accessFloorPOI['isOwner']! ||
            accessFloorPOI['isAdmin']! ||
            _isSuperAdmin)) {
          throw Exception('You dont have access to delete');
        }
        operations.add(DBConnection.deletePOI(poiId, mapId));
      }

      // User deletion (admin only)
      if (_deleteUserController.text.isNotEmpty) {
        if (!_isSuperAdmin) throw Exception('Super Admin Required');
        final userId = int.tryParse(_deleteUserController.text);
        if (userId == null) throw Exception('Invalid User ID');

        operations.add(DBConnection.deleteUser(userId));
      }

      // Admin management (super admin only)
      if (_revokeAdminController.text.isNotEmpty) {
        if (!_isSuperAdmin) throw Exception('Super Admin Required');
        final userId = int.tryParse(_revokeAdminController.text);
        if (userId == null) throw Exception('Invalid User ID');

        operations.add(DBConnection.revokeAdmin(userId));
      }

      if (_grantAdminController.text.isNotEmpty) {
        if (!_isSuperAdmin) throw Exception('Super Admin Required');
        final userId = int.tryParse(_grantAdminController.text);
        if (userId == null) throw Exception('Invalid User ID');

        operations.add(DBConnection.grantAdmin(userId));
      }

      await Future.wait(operations);
      setState(() => _message = 'Operations completed successfully');
    }  on OutOfMemoryError {
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
      appBar: AppBar(title: const Text('Admin Management')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Section 1: Map Deletion
              const Text('Map Deletion',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: _deleteMapController,
                decoration: const InputDecoration(
                  labelText: 'Map ID to Delete',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const Divider(),
              const SizedBox(height: 20),

              // Section 2: Floor Deletion
              const Text('Floor & POI Deletion',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: _deleteWithMapController,
                decoration: const InputDecoration(
                  labelText: 'Map ID (Required for deleting Floor or POI)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _floorIdController,
                decoration: const InputDecoration(
                  labelText: 'Floor ID to Delete',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),

              // Section 3: POI Deletion
              const SizedBox(height: 10),
              TextField(
                controller: _poiIdController,
                decoration: const InputDecoration(
                  labelText: 'POI ID to Delete',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const Divider(),
              const SizedBox(height: 20),

              // Section 4: User Management
              const Text('User Management',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: _deleteUserController,
                decoration: const InputDecoration(
                  labelText: 'User ID to Delete (Admin only)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _revokeAdminController,
                decoration: const InputDecoration(
                  labelText: 'Revoke Admin (User 1 only)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _grantAdminController,
                decoration: const InputDecoration(
                  labelText: 'Grant Admin (User 1 only)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const Divider(),
              const SizedBox(height: 20),

              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _submitForm,
                      child: const Text('Execute Selected Operations'),
                    ),
              const SizedBox(height: 20),

              Text(
                _message,
                style: TextStyle(
                  color: _message.contains('Error') ? Colors.red : Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _deleteMapController.dispose();
    _deleteWithMapController.dispose();
    _floorIdController.dispose();
    _poiIdController.dispose();
    _deleteUserController.dispose();
    _revokeAdminController.dispose();
    _grantAdminController.dispose();
    super.dispose();
  }
}

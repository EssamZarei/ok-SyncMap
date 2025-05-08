import 'package:flutter/material.dart';
import '../DBConnection.dart';
import '../Login.dart';

class EditPOIWidget extends StatefulWidget {
  const EditPOIWidget({super.key});

  @override
  State<EditPOIWidget> createState() => _EditPOIWidgetState();
}

class _EditPOIWidgetState extends State<EditPOIWidget> {
  final TextEditingController _mapIdController = TextEditingController();
  final TextEditingController _poiIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _yController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addUserController = TextEditingController();
  final TextEditingController _removeUserController = TextEditingController();

  String _message = '';
  bool _isLoading = false;
  bool _canEditDate = false;
  bool _showUserManagement = false;
  bool _poiLoaded = false;
  String? _selectedIcon;

  // List of available icons for POI types
  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'Restroom', 'icon': Icons.wc, 'value': 'wc'},
    {'name': 'Elevator', 'icon': Icons.elevator, 'value': 'elevator'},
    {'name': 'Stairs', 'icon': Icons.stairs, 'value': 'stairs'},
    {'name': 'Exit', 'icon': Icons.exit_to_app, 'value': 'exit'},
    {'name': 'Restaurant', 'icon': Icons.restaurant, 'value': 'restaurant'},
    {'name': 'Cafe', 'icon': Icons.local_cafe, 'value': 'cafe'},
    {'name': 'Store', 'icon': Icons.shopping_cart, 'value': 'store'},
    {'name': 'Information', 'icon': Icons.info, 'value': 'info'},
    {'name': 'Medical', 'icon': Icons.local_hospital, 'value': 'medical'},
    {'name': 'Office', 'icon': Icons.work, 'value': 'office'},
  ];

  Future<void> _loadPOIAndCheckPermissions() async {
    final currentUserId = Login.getCurrentUserId();
    if (currentUserId == null) {
      setState(() => _message = 'Error User not logged in');
      return;
    }

    final mapId = int.tryParse(_mapIdController.text);
    final poiId = int.tryParse(_poiIdController.text);
    if (mapId == null || poiId == null) {
      setState(() => _message = 'Invalid Map ID or POI ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // Check permissions
      final isAdmin = await DBConnection.isUserAdmin(currentUserId);
      final isOwner = await DBConnection.isUserMapOwner(currentUserId, mapId);
      final hasAccess = await DBConnection.doesUserHavePOIAccess(currentUserId, poiId);

      if (!(isAdmin || isOwner || hasAccess)) {
        throw Exception('No permission to edit this POI');
      }

      // Load POI data
      final poiInfo = await DBConnection.getPOIData(poiId);
      if (poiInfo == null) throw Exception('POI not found');

      // Set up UI state
      setState(() {
        _canEditDate = isAdmin || isOwner;
        _showUserManagement = isAdmin || isOwner;
        _poiLoaded = true;
        
        // Pre-fill current values
        _nameController.text = poiInfo['PName'] ?? '';
        _xController.text = poiInfo['PX']?.toString() ?? '';
        _yController.text = poiInfo['PY']?.toString() ?? '';
        _descriptionController.text = poiInfo['PDescription'] ?? '';
        _selectedIcon = poiInfo['PIconName'];
        
        // Handle date
        final editMonth = poiInfo['PEditMonth'];
        final editYear = poiInfo['PEditYear'];
        
        if (editMonth != null) {
          _monthController.text = editMonth.toString();
        }
        if (editYear != null) {
          _yearController.text = editYear.toString();
        }
      });

    } catch (e) {
      setState(() {
        _message = 'Error: ${e.toString()}';
        _poiLoaded = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePOI() async {
    final currentUserId = Login.getCurrentUserId();
    if (currentUserId == null) {
      setState(() => _message = 'User not logged in');
      return;
    }

    final mapId = int.tryParse(_mapIdController.text);
    final poiId = int.tryParse(_poiIdController.text);
    if (mapId == null || poiId == null) {
      setState(() => _message = 'Invalid Map ID or POI ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // Validate date if being edited
      if (_monthController.text.isNotEmpty || _yearController.text.isNotEmpty) {
        final month = int.tryParse(_monthController.text) ?? DateTime.now().month;
        final year = int.tryParse(_yearController.text) ?? DateTime.now().year % 100;
        final now = DateTime.now();
        
        if (year < now.year % 100 || 
            (year == now.year % 100 && month < now.month)) {
          throw Exception('Date must be current or future month');
        }
      }

      // Prepare update
      final success = await DBConnection.updatePOI(
        poiId: poiId,
        mapId: mapId,
        newName: _nameController.text.isNotEmpty ? _nameController.text : null,
        newX: _xController.text.isNotEmpty ? int.tryParse(_xController.text) : null,
        newY: _yController.text.isNotEmpty ? int.tryParse(_yController.text) : null,
        newMonth: _monthController.text.isNotEmpty ? int.tryParse(_monthController.text) : null,
        newYear: _yearController.text.isNotEmpty ? int.tryParse(_yearController.text) : null,
        newDescription: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        newIconName: _selectedIcon,
      );

      setState(() => _message = success ? 'POI updated successfully' : 'Failed to update POI');
    } catch (e) {
      setState(() => _message = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _manageUserAccess(bool isAdd) async {
    final currentUserId = Login.getCurrentUserId();
    if (currentUserId == null) {
      setState(() => _message = 'User not logged in');
      return;
    }

    final mapId = int.tryParse(_mapIdController.text);
    final poiId = int.tryParse(_poiIdController.text);
    final targetUserId = int.tryParse(isAdd ? _addUserController.text : _removeUserController.text);
    
    if (mapId == null || poiId == null || targetUserId == null) {
      setState(() => _message = 'Invalid IDs');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final isAdmin = await DBConnection.isUserAdmin(currentUserId);
      final isOwner = await DBConnection.isUserMapOwner(currentUserId, mapId);

      if (!isAdmin && !isOwner) {
        throw Exception('Only admin/owner can manage user access');
      }

      final success = isAdd
          ? await DBConnection.addUserPOIRelation(targetUserId, poiId)
          : await DBConnection.removeUserPOIRelation(targetUserId, poiId);

      setState(() {
        _message = success 
            ? 'User access ${isAdd ? 'granted' : 'revoked'} successfully'
            : 'Failed to ${isAdd ? 'add' : 'remove'} user access';
        
        if (isAdd) _addUserController.clear();
        else _removeUserController.clear();
      });
    }on OutOfMemoryError {
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
      appBar: AppBar(title: const Text('Edit POI')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Required IDs
              TextField(
                controller: _mapIdController,
                decoration: const InputDecoration(labelText: 'Map ID*',
                border: OutlineInputBorder()
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _poiIdController,
                decoration: const InputDecoration(labelText: 'POI ID*',
                border: OutlineInputBorder()
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loadPOIAndCheckPermissions,
                child: const Text('Load POI'),
              ),
              const SizedBox(height: 20),

              if (_poiLoaded) ...[
                // POI Edit Fields
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'POI Name'),
                ),
                const SizedBox(height: 10),

                // Icon Selection
                const Text('POI Icon:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _iconOptions.map((icon) {
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon['icon'], size: 20),
                          const SizedBox(width: 4),
                          Text(icon['name']),
                        ],
                      ),
                      selected: _selectedIcon == icon['value'],
                      onSelected: (selected) {
                        setState(() {
                          _selectedIcon = selected ? icon['value'] : null;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Coordinates
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _xController,
                        decoration: const InputDecoration(labelText: 'X Coordinate'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _yController,
                        decoration: const InputDecoration(labelText: 'Y Coordinate'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),

                // Date fields (admin/owner only)
                if (_canEditDate) ...[
                  const Text('Edit Date (Admin/Owner Only)', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _monthController,
                          decoration: const InputDecoration(labelText: 'Month (1-12)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _yearController,
                          decoration: const InputDecoration(labelText: 'Year (YY)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // User management (admin/owner only)
                if (_showUserManagement) ...[
                  const Divider(),
                  const Text('User Access Management', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _addUserController,
                    decoration: InputDecoration(
                      labelText: 'Grant Access to User ID',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _manageUserAccess(true),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _removeUserController,
                    decoration: InputDecoration(
                      labelText: 'Revoke Access from User ID',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () => _manageUserAccess(false),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                ],

                // Submit button
                ElevatedButton(
                  onPressed: _updatePOI,
                  child: const Text('Update POI'),
                ),
                const SizedBox(height: 10),
              ],

              // Status message
              Text(
                _message,
                style: TextStyle(
                  color: _message.contains('Error') ? Colors.red : Colors.blue,
                ),
              ),

              if (_isLoading) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapIdController.dispose();
    _poiIdController.dispose();
    _nameController.dispose();
    _xController.dispose();
    _yController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _descriptionController.dispose();
    _addUserController.dispose();
    _removeUserController.dispose();
    super.dispose();
  }
}




/*
import 'package:flutter/material.dart';
import '../DBConnection.dart';
import '../Login.dart';

class EditPOIWidget extends StatefulWidget {
  const EditPOIWidget({super.key});

  @override
  State<EditPOIWidget> createState() => _EditPOIWidgetState();
}

class _EditPOIWidgetState extends State<EditPOIWidget> {
  final TextEditingController _mapIdController = TextEditingController();
  final TextEditingController _poiIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _yController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addUserController = TextEditingController();
  final TextEditingController _removeUserController = TextEditingController();

  String _message = '';
  bool _isLoading = false;
  bool _canEditDate = false;
  bool _showUserManagement = false;
  bool _poiLoaded = false;
  String? _selectedIcon;

  // List of available icons for POI types
  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'Restroom', 'icon': Icons.wc, 'value': 'wc'},
    {'name': 'Elevator', 'icon': Icons.elevator, 'value': 'elevator'},
    {'name': 'Stairs', 'icon': Icons.stairs, 'value': 'stairs'},
    {'name': 'Exit', 'icon': Icons.exit_to_app, 'value': 'exit'},
    {'name': 'Restaurant', 'icon': Icons.restaurant, 'value': 'restaurant'},
    {'name': 'Cafe', 'icon': Icons.local_cafe, 'value': 'cafe'},
    {'name': 'Store', 'icon': Icons.shopping_cart, 'value': 'store'},
    {'name': 'Information', 'icon': Icons.info, 'value': 'info'},
    {'name': 'Medical', 'icon': Icons.local_hospital, 'value': 'medical'},
    {'name': 'Office', 'icon': Icons.work, 'value': 'office'},
  ];

  Future<void> _loadPOIAndCheckPermissions() async {
    final currentUserId = Login.getCurrentUserId();
    if (currentUserId == null) {
      setState(() => _message = 'User not logged in');
      return;
    }

    final mapId = int.tryParse(_mapIdController.text);
    final poiId = int.tryParse(_poiIdController.text);
    if (mapId == null || poiId == null) {
      setState(() => _message = 'Invalid Map ID or POI ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // Check permissions
      final isAdmin = await DBConnection.isUserAdmin(currentUserId);
      final isOwner = await DBConnection.isUserMapOwner(currentUserId, mapId);
      final hasAccess = await DBConnection.doesUserHavePOIAccess(currentUserId, poiId);

      if (!(isAdmin || isOwner || hasAccess)) {
        throw Exception('No permission to edit this POI');
      }

      // Load POI data
      final poiInfo = await DBConnection.getPOIData(poiId);
      if (poiInfo == null) throw Exception('POI not found');

      // Set up UI state
      setState(() {
        _canEditDate = isAdmin || isOwner;
        _showUserManagement = isAdmin || isOwner;
        _poiLoaded = true;
        
        // Pre-fill current values
        _nameController.text = poiInfo['PName'] ?? '';
        _xController.text = poiInfo['PX']?.toString() ?? '';
        _yController.text = poiInfo['PY']?.toString() ?? '';
        _descriptionController.text = poiInfo['PDescription'] ?? '';
        _selectedIcon = poiInfo['PIconName'];
        
        // Handle date
        final editMonth = poiInfo['PEditMonth'];
        final editYear = poiInfo['PEditYear'];
        
        if (editMonth != null) {
          _monthController.text = editMonth.toString();
        }
        if (editYear != null) {
          _yearController.text = editYear.toString();
        }
      });

    } catch (e) {
      setState(() {
        _message = 'Error: ${e.toString()}';
        _poiLoaded = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePOI() async {
    final currentUserId = Login.getCurrentUserId();
    if (currentUserId == null) {
      setState(() => _message = 'User not logged in');
      return;
    }

    final mapId = int.tryParse(_mapIdController.text);
    final poiId = int.tryParse(_poiIdController.text);
    if (mapId == null || poiId == null) {
      setState(() => _message = 'Invalid Map ID or POI ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // Validate date if being edited
      if (_monthController.text.isNotEmpty || _yearController.text.isNotEmpty) {
        final month = int.tryParse(_monthController.text) ?? DateTime.now().month;
        final year = int.tryParse(_yearController.text) ?? DateTime.now().year % 100;
        final now = DateTime.now();
        
        if (year < now.year % 100 || 
            (year == now.year % 100 && month < now.month)) {
          throw Exception('Date must be current or future month');
        }
      }

      // Prepare update
      final success = await DBConnection.updatePOI(
        poiId: poiId,
        mapId: mapId,
        newName: _nameController.text.isNotEmpty ? _nameController.text : null,
        newX: _xController.text.isNotEmpty ? int.tryParse(_xController.text) : null,
        newY: _yController.text.isNotEmpty ? int.tryParse(_yController.text) : null,
        newMonth: _monthController.text.isNotEmpty ? int.tryParse(_monthController.text) : null,
        newYear: _yearController.text.isNotEmpty ? int.tryParse(_yearController.text) : null,
        newDescription: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        newIconName: _selectedIcon,
      );

      setState(() => _message = success ? 'POI updated successfully' : 'Failed to update POI');
    } catch (e) {
      setState(() => _message = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _manageUserAccess(bool isAdd) async {
    final currentUserId = Login.getCurrentUserId();
    if (currentUserId == null) {
      setState(() => _message = 'User not logged in');
      return;
    }

    final mapId = int.tryParse(_mapIdController.text);
    final poiId = int.tryParse(_poiIdController.text);
    final targetUserId = int.tryParse(isAdd ? _addUserController.text : _removeUserController.text);
    
    if (mapId == null || poiId == null || targetUserId == null) {
      setState(() => _message = 'Invalid IDs');
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      final isAdmin = await DBConnection.isUserAdmin(currentUserId);
      final isOwner = await DBConnection.isUserMapOwner(currentUserId, mapId);

      if (!isAdmin && !isOwner) {
        throw Exception('Only admin/owner can manage user access');
      }

      final success = isAdd
          ? await DBConnection.addUserPOIRelation(targetUserId, poiId)
          : await DBConnection.removeUserPOIRelation(targetUserId, poiId);

      setState(() {
        _message = success 
            ? 'User access ${isAdd ? 'granted' : 'revoked'} successfully'
            : 'Failed to ${isAdd ? 'add' : 'remove'} user access';
        
        if (isAdd) _addUserController.clear();
        else _removeUserController.clear();
      });
    } catch (e) {
      setState(() => _message = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit POI')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Required IDs
              TextField(
                controller: _mapIdController,
                decoration: const InputDecoration(labelText: 'Map ID*'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _poiIdController,
                decoration: const InputDecoration(labelText: 'POI ID*'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loadPOIAndCheckPermissions,
                child: const Text('Load POI'),
              ),
              const SizedBox(height: 20),

              if (_poiLoaded) ...[
                // POI Edit Fields
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'POI Name'),
                ),
                const SizedBox(height: 10),

                // Icon Selection
                const Text('POI Icon:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _iconOptions.map((icon) {
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon['icon'], size: 20),
                          const SizedBox(width: 4),
                          Text(icon['name']),
                        ],
                      ),
                      selected: _selectedIcon == icon['value'],
                      onSelected: (selected) {
                        setState(() {
                          _selectedIcon = selected ? icon['value'] : null;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Coordinates
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _xController,
                        decoration: const InputDecoration(labelText: 'X Coordinate'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _yController,
                        decoration: const InputDecoration(labelText: 'Y Coordinate'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),

                // Date fields (admin/owner only)
                if (_canEditDate) ...[
                  const Text('Edit Date (Admin/Owner Only)', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _monthController,
                          decoration: const InputDecoration(labelText: 'Month (1-12)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _yearController,
                          decoration: const InputDecoration(labelText: 'Year (YY)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // User management (admin/owner only)
                if (_showUserManagement) ...[
                  const Divider(),
                  const Text('User Access Management', 
                    style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _addUserController,
                    decoration: InputDecoration(
                      labelText: 'Grant Access to User ID',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _manageUserAccess(true),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _removeUserController,
                    decoration: InputDecoration(
                      labelText: 'Revoke Access from User ID',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () => _manageUserAccess(false),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                ],

                // Submit button
                ElevatedButton(
                  onPressed: _updatePOI,
                  child: const Text('Update POI'),
                ),
                const SizedBox(height: 10),
              ],

              // Status message
              Text(
                _message,
                style: TextStyle(
                  color: _message.contains('Error') ? Colors.red : Colors.blue,
                ),
              ),

              if (_isLoading) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapIdController.dispose();
    _poiIdController.dispose();
    _nameController.dispose();
    _xController.dispose();
    _yController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _descriptionController.dispose();
    _addUserController.dispose();
    _removeUserController.dispose();
    super.dispose();
  }
}
*/
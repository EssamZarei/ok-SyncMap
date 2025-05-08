import 'package:flutter/material.dart';
import 'package:myfirst/EditPOI.dart';
import 'package:myfirst/ViewPOI.dart';
import '../DBConnection.dart';
import '../Login.dart';

class AddPOIWidget extends StatefulWidget {
  const AddPOIWidget({super.key});

  @override
  State<AddPOIWidget> createState() => _AddPOIWidgetState();
}

class _AddPOIWidgetState extends State<AddPOIWidget> {
  final TextEditingController _mapIdController = TextEditingController();
  final TextEditingController _floorIdController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _yController = TextEditingController();

  final TextEditingController _monthController = TextEditingController(
    text: DateTime.now().month.toString(),
  );

  final TextEditingController _yearController = TextEditingController(
    text: DateTime.now().year.toString(),
  );

  final TextEditingController _descriptionController = TextEditingController();

  String _message = '';
  bool _isLoading = false;
  String? _selectedIcon;

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

  Future<void> _addPOI() async {
    final currentUserId = Login.getCurrentUserId();
    if (currentUserId == null) {
      setState(() => _message = 'Error User not logged in');
      return;
    }

    // Validate required fields
    if (_mapIdController.text.isEmpty ||
        _floorIdController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _xController.text.isEmpty ||
        _yController.text.isEmpty ||
        _monthController.text.isEmpty ||
        _yearController.text.isEmpty) {
      setState(() => _message = 'Please fill all required fields');
      return;
    }

    int? mapId = int.tryParse(_mapIdController.text);
    int? floorId = int.tryParse(_floorIdController.text);
    int? month = int.tryParse(_monthController.text);
    int? year = int.tryParse(_yearController.text);

    if (mapId == null || floorId == null || month == null || year == null) {
      setState(() => _message = 'Invalid numeric values');
      return;
    }

    if (month < 1 || month > 12) {
      setState(() => _message = 'Month must be between 1-12');
      return;
    }

    setState(() {
      _message = '';
      _isLoading = true;
    });

    try {
      final isAdmin = await DBConnection.isUserAdmin(currentUserId);
      final isOwner = await DBConnection.isUserMapOwner(currentUserId, mapId);

      if (!isAdmin && !isOwner) {
        throw Exception('You need admin rights or map ownership to add POIs');
      }

      final newPoiId = await DBConnection.addPOI(
        fid: floorId,
        mid: mapId,
        px: int.parse(_xController.text),
        py: int.parse(_yController.text),
        pName: _nameController.text,
        editMonth: month,
        editYear: year,
        pDescription: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        pIconName: _selectedIcon,
      );

      if (newPoiId != null) {
        setState(() => _message = 'POI added successfully! ID: ${newPoiId}');
        _clearForm();
      } else {
        setState(() => _message = 'Failed to add POI');
      }
    }  on OutOfMemoryError {
      print("Critical error: Device memory full!");
    }catch (e) {
      setState(() => _message = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _mapIdController.clear();
    _floorIdController.clear();
    _nameController.clear();
    _xController.clear();
    _yController.clear();
    _monthController.text = DateTime.now().month.toString();
    _yearController.text = DateTime.now().year.toString();
    _descriptionController.clear();
    setState(() => _selectedIcon = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New POI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearForm,
            tooltip: 'Clear Form',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ViewPOI()),
                );
              },
              child: const Text('View POI'),
            ),
            SizedBox(height: 16,),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditPOIWidget()),
                );
              },
              child: const Text('Edit POI'),
            ),
            SizedBox(height: 16,),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _mapIdController,
                  decoration: const InputDecoration(
                    labelText: 'Map ID*',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _floorIdController,
                  decoration: const InputDecoration(
                    labelText: 'Floor ID*',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                // POI Name
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'POI Name*',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Icon Selection
                const Text('POI Type (optional):',
                    style: TextStyle(fontSize: 16)),
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
                const SizedBox(height: 24),

                // Coordinates
                const Text('Coordinates:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _xController,
                        decoration: const InputDecoration(
                          labelText: 'X Position*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _yController,
                        decoration: const InputDecoration(
                          labelText: 'Y Position*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Last Edit Date
                const Text('Last Edit Date:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _monthController,
                        decoration: const InputDecoration(
                          labelText: 'Month (1-12)*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _yearController,
                        decoration: const InputDecoration(
                          labelText: 'Year (YYYY)*',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _addPOI,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Add POI'),
                ),
                const SizedBox(height: 16),

                // Status Message
                Text(
                  _message,
                  style: TextStyle(
                    color:
                        _message.contains('Error') ? Colors.red : Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapIdController.dispose();
    _floorIdController.dispose();
    _nameController.dispose();
    _xController.dispose();
    _yController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

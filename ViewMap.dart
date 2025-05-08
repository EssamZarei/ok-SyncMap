import 'package:flutter/material.dart';
import 'package:myfirst/ViewFloor.dart';
import 'package:url_launcher/url_launcher.dart';
import '../DBConnection.dart';

class MapsWithFloorsView extends StatefulWidget {
  const MapsWithFloorsView({super.key});

  @override
  State<MapsWithFloorsView> createState() => _MapsWithFloorsViewState();
}

class _MapsWithFloorsViewState extends State<MapsWithFloorsView> {

  List<Map<String, dynamic>> _allMaps = [];
  List<Map<String, dynamic>> _filteredMaps = [];

  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadMaps();
    _searchController.addListener(_filterMaps);
  }

  Future<void> _loadMaps() async {
    try {
      final data = await DBConnection.getMapsWithFloors();
      setState(() {
        _allMaps = data;
        _filteredMaps = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load maps: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _filterMaps() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMaps = _allMaps.where((map) {
        final mapData = map['map'];
        return mapData['MName']?.toString().toLowerCase().contains(query) == true ||
            mapData['MCity']?.toString().toLowerCase().contains(query) == true ||
            mapData['MType']?.toString().toLowerCase().contains(query) == true ||
            mapData['MID']?.toString().contains(query) == true ||
            mapData['UID']?.toString().contains(query) == true ;
            // ||
            // (map['floors'] as List).any((floor) => 
            //     floor['FName']?.toString().toLowerCase().contains(query) == true);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maps & Floors'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search maps...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => IndoorMapScreen()),
                  );
                },
                child: const Text('View Floor 🗺️'),
              ),
              const SizedBox(height: 16),
          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(child: Text(_errorMessage))
                    : _filteredMaps.isEmpty
                        ? const Center(child: Text('No matching maps found'))
                        : ListView.builder(
                            itemCount: _filteredMaps.length,
                            itemBuilder: (context, index) {
                              final mapData = _filteredMaps[index]['map'];
                              final floors = _filteredMaps[index]['floors'] as List;

                              return Card(
                                margin: const EdgeInsets.all(12),
                                elevation: 4,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Map header
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.map_outlined,
                                            size: 40,
                                             color: Colors.blue,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  mapData['MName'] ?? 'Unnamed Map',
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '${mapData['MCity']} • ${mapData['MType']}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Map details
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          Chip(
                                            avatar: const Icon(Icons.numbers, size: 18),
                                            label: Text('Map ID: ${mapData['MID']}'),
                                            backgroundColor: Colors.grey[100],
                                          ),
                                          Chip(
                                            avatar: const Icon(Icons.person_outline, size: 18),
                                            label: Text('Owner ID: ${mapData['UID']}'),
                                            backgroundColor: Colors.grey[100],
                                          ),
                                          if (mapData['MLocationURL'] != null &&
                                              mapData['MLocationURL'].toString().trim().isNotEmpty)
                                            InkWell(
                                              onTap: () async {
                                                final url = Uri.parse(mapData['MLocationURL']);
                                                if (await canLaunchUrl(url)) {
                                                  await launchUrl(
                                                    url,
                                                    mode: LaunchMode.externalApplication,
                                                  );
                                                }
                                              },
                                              child: Chip(
                                                avatar: const Icon(Icons.location_on_outlined, size: 18),
                                                label: const Text('Location'),
                                                backgroundColor: Colors.grey[100],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Floors
                                      const Text(
                                        'Floors:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      floors.isEmpty
                                          ? const Text(
                                              'No floors available',
                                              style: TextStyle(color: Colors.grey),
                                            )
                                          : Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: floors.map((floor) => Chip(
                                                avatar: const Icon(Icons.layers_outlined, size: 18),
                                                label: Text('${floor['FName']} (ID: ${floor['FID']})'),
                                                backgroundColor: Colors.grey[100],
                                              )).toList(),
                                            ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}



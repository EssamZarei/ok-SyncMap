import 'package:flutter/material.dart';
import '../DBConnection.dart';
import 'package:audioplayers/audioplayers.dart';
import './ApiService.dart';
import 'package:flutter/foundation.dart';

class ViewPOI extends StatefulWidget {
  const ViewPOI({super.key});
  @override
  State<ViewPOI> createState() => _ViewPOIState();
}

class _ViewPOIState extends State<ViewPOI> {
  final TextEditingController _controller = TextEditingController();
  final AudioPlayer _player = AudioPlayer();

  String poiInfo = '', poiName = '';
  String? audioPath;
  IconData? poiIcon;
  bool isLoading = false, isConverting = false;

  final icons = {
    'wc': Icons.wc,
    'elevator': Icons.elevator,
    'stairs': Icons.stairs,
    'exit': Icons.exit_to_app,
    'restaurant': Icons.restaurant,
    'cafe': Icons.local_cafe,
    'store': Icons.shopping_cart,
    'info': Icons.info,
    'medical': Icons.local_hospital,
    'office': Icons.work,
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final text = _controller.text.trim();
      if (text.isNotEmpty && int.tryParse(text) != null) _fetchPOI();
    });
  }

  Future<void> _fetchPOI() async {
    setState(() => isLoading = true);
    try {
      final data = await DBConnection.getPOIData(int.parse(_controller.text));
      if (data == null) {
        setState(() {
          poiInfo = 'POI not found';
          audioPath = null;
        });
        return;
      }
      setState(() {
        poiName = data['PName'] ?? 'Unnamed';
        poiIcon = icons[data['PIconName']] ?? Icons.place;
        poiInfo = '''
Name: ${data['PName'] ?? 'Unnamed'}
Description: ${data['PDescription'] ?? 'No description'}

Map ID: ${data['MID']}
Floor: ${data['FID']}
Edit Unril: ${data['PEditMonth']}/${data['PEditYear']}
Coordinates: X: ${data['PX']} | Y: ${data['PY']}
''';
        audioPath = null;
      });
    }  on OutOfMemoryError {
      print("Critical error: Device memory full!");
    }catch (e) {
      setState(() {
        poiInfo = 'Invalid POI ID';
        audioPath = null;
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _speak() async {
    if (poiInfo.isEmpty || poiInfo.contains('Invalid') || poiInfo.contains('not found')) return;
    setState(() => isConverting = true);
    final audio = await ApiService.textToSpeech(
      "POI information for $poiName. ${poiInfo.replaceAll(':', '.')}",
    );
    setState(() {
      audioPath = audio?.path;
      isConverting = false;
    });
    if (audioPath != null) {
      await _player.play(kIsWeb ? UrlSource(audioPath!) : DeviceFileSource(audioPath!));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('View POI')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Enter POI ID', border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          if (poiInfo.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(), borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (poiIcon != null)
                        Row(children: [
                          Icon(poiIcon, size: 40, color: Colors.blue,),
                          const SizedBox(width: 10),
                          Text(poiName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        ]),
                        Divider(),
                      const SizedBox(height: 16),
                      Text(poiInfo),
                      const SizedBox(height: 16),
                      IconButton(
                        icon: isConverting
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.volume_up, size: 36),
                        onPressed: isConverting ? null : _speak,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

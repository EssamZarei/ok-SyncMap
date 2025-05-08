import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myfirst/AddPOI.dart';
import '../DBConnection.dart';

class IndoorMapScreen extends StatefulWidget {
  @override
  _IndoorMapScreenState createState() => _IndoorMapScreenState();
}

class _IndoorMapScreenState extends State<IndoorMapScreen> {
  final _floorIdController = TextEditingController();
  final _transformationController = TransformationController();
  final _imageKey = GlobalKey();
  final List<Map<String, dynamic>> points = [];

  Size? _imageSize;
  bool _isLoading = false, _imageLoaded = false;
  String _message = '';

  Map<String, dynamic>? _floorData;
  Offset? _pointerPosition;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(() => setState(() =>
        _currentScale = _transformationController.value.getMaxScaleOnAxis()));
  }

  @override
  void dispose() {
    _floorIdController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadFloorData() async {
    final floorId = int.tryParse(_floorIdController.text);
    if (floorId == null)
      return setState(() => _message = 'Please enter a valid floor ID');

    setState(() {
      _isLoading = true;
      _message = '';
      _floorData = null;
      points.clear();
      _imageLoaded = false;
    });

    try {
      _floorData = await DBConnection.getFloorDetailsWithMapInfo(floorId);
      if (_floorData == null)
        return setState(() => _message = 'Floor not found');

      final pois = await DBConnection.getPOIsByFloorId(floorId);

      setState(() => points.addAll(pois.map((poi) => {
            'x': poi['x'].toDouble(),
            'y': poi['y'].toDouble(),
            'name': poi['name'],
            'icon': _getIconFromName(poi['icon']),
            'PID': poi['pid'],
          })));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          setState(() {
            _imageSize = box.size;
            _imageLoaded = true;
          });
        }
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

  IconData _getIconFromName(String? iconName) =>
      {
        'wc': Icons.wc,
        'elevator': Icons.elevator,
        'stairs': Icons.stairs,
        'restaurant': Icons.restaurant,
        'cafe': Icons.local_cafe,
        'store': Icons.shopping_cart,
        'info': Icons.info,
        'medical': Icons.local_hospital,
        'office': Icons.work,
      }[iconName] ??
      Icons.place;

  void _handleImageTap(TapDownDetails details) {
    if (!_imageLoaded || _imageSize == null || _floorData == null) return;
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox;
    setState(() => _pointerPosition = MatrixUtils.transformPoint(
        Matrix4.inverted(_transformationController.value),
        box.globalToLocal(details.globalPosition)));
  }

  Widget _buildCoordinateDisplay(String label, dynamic value) => Column(
        children: [
          Text(label, style: TextStyle(color: Colors.white)),
          Text(value?.toString() ?? '--',
              style: TextStyle(color: Colors.white, fontSize: 20)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Indoor Map')),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.black.withOpacity(0.7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCoordinateDisplay('X:', _pointerPosition?.dx.toInt()),
                _buildCoordinateDisplay('Y:', _pointerPosition?.dy.toInt()),
                _buildCoordinateDisplay(
                    'Zoom:', '${_currentScale.toStringAsFixed(2)}x'),
              ],
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddPOIWidget()),
              );
            },
            child: const Text('POI Access 🎟️'),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _floorIdController,
                    decoration: InputDecoration(
                      labelText: 'Enter Floor ID',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _loadFloorData,
                  child: _isLoading
                      ? CircularProgressIndicator()
                      : Text('Load Floor'),
                ),
              ],
            ),
          ),
          if (_floorData != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Map: ${_floorData!['MID']} | ${_floorData!['MName']}',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text('Floor: ${_floorData!['FID']} | ${_floorData!['FName']}',
                      style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ],
          Expanded(
            child: Stack(
              children: [
                if (_floorData != null) ...[
                  if (_floorData!['FImage'] != null)
                    InteractiveViewer(
                      transformationController: _transformationController,
                      boundaryMargin: EdgeInsets.all(double.infinity),
                      minScale: 0.1,
                      maxScale: 4.0,
                      child: GestureDetector(
                        onTapDown: _handleImageTap,
                        child: Image.file(
                          File(_floorData!['FImage'].toString()),
                          key: _imageKey,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Image load failed'),
                                Text(
                                    'Path: ${_floorData!['FImage'].toString()}'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Center(child: Text('No floor image available')),
                  ...points.map((point) => Positioned(
                        left: MatrixUtils.transformPoint(
                          _transformationController.value,
                          Offset(point['x'], point['y']),
                        ).dx,
                        top: MatrixUtils.transformPoint(
                          _transformationController.value,
                          Offset(point['x'], point['y']),
                        ).dy,
                        child: Transform.scale(
                          scale: 1 / _currentScale,
                          child: Column(
                            children: [
                              Icon(point['icon'], color: Colors.blue, size: 24),
                              Text('${point['name']}\n${point['PID']}',
                                  style: TextStyle(
                                      color: Colors.black, fontSize: 12)),
                            ],
                          ),
                        ),
                      )),
                  if (_pointerPosition != null)
                    Positioned(
                      left: MatrixUtils.transformPoint(
                              _transformationController.value,
                              _pointerPosition!)
                          .dx,
                      top: MatrixUtils.transformPoint(
                              _transformationController.value,
                              _pointerPosition!)
                          .dy,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_message,
                  style: TextStyle(
                      color: _message.contains('Error')
                          ? Colors.red
                          : Colors.blue)),
            )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.content_copy),
        onPressed: _pointerPosition == null
            ? null
            : () {
                Clipboard.setData(ClipboardData(
                    text:
                        'X: ${_pointerPosition!.dx.toInt()}, Y: ${_pointerPosition!.dy.toInt()}'));
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Coordinates copied!')));
              },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:typed_data';
import 'dart:async';

class BMSServiceScreen extends StatefulWidget {
  final BluetoothService service;

  const BMSServiceScreen({Key? key, required this.service}) : super(key: key);

  @override
  State<BMSServiceScreen> createState() => _BMSServiceScreenState();
}

class _BMSServiceScreenState extends State<BMSServiceScreen> {
  // Constants
  static const Map<String, String> uuidToName = {
    'ACDEB138-3BD0-4BB3-B159-19F6F70871ED': 'State of Charge',
    'AC0768DF-2F49-43D4-B23D-1DC82C90A9E9': 'Voltage',
    '6FEEC926-BA3C-4E65-BC71-5DB481811186': 'Current',
    '9DEA1343-434F-4555-A0A1-BB43FCBC68A6': 'Power',
    '49267B41-560F-4CFF-ADC8-90EF85D2BE20': 'Highest Cell',
    'B9D01E5C-3751-4092-8B06-6D1FFF479E77': 'Lowest Cell',
    '0EA08B6D-C905-4D9D-93F8-51E35DA096FC': 'Highest Temperature',
    '26CD6E8A-175D-4C8E-B487-DEFF0B034F2A': 'Lowest Temperature',
    '396C768B-F348-44CC-9D46-92388F25A557': 'Failure Level',
    '1C45825B-7C81-430B-8D5F-B644FFFC71BB': 'Voltage Difference',
  };

  final Map<String, Stream<List<int>>> _characteristicStreams = {};
  final Map<String, List<int>> _characteristicValues = {};
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _setupCharacteristicStreams();
  }

  void _setupCharacteristicStreams() {
    for (BluetoothCharacteristic c in widget.service.characteristics) {
      try {
        _characteristicStreams[c.uuid.str] = c.lastValueStream;
        _characteristicStreams[c.uuid.str]?.listen(
          (value) {
            if (mounted) {
              setState(() => _characteristicValues[c.uuid.str] = value);
            }
          },
          onError: (error) {
            debugPrint('Error listening to characteristic ${c.uuid.str}: $error');
          },
        );

        // Initial read
        if (c.properties.read) {
          c.read().then((value) {
            if (mounted) {
              setState(() => _characteristicValues[c.uuid.str] = value);
            }
          }).catchError((error) {
            debugPrint('Error reading characteristic ${c.uuid.str}: $error');
          });
        }
      } catch (e) {
        debugPrint('Error setting up characteristic ${c.uuid.str}: $e');
      }
    }
  }

  String _getCharacteristicDisplayValue(String uuid, List<int>? value) {
    if (value == null || value.isEmpty) return 'No value';

    // Convert bytes to float
    try {
      final bytes = Uint8List.fromList(value);
      final buffer = bytes.buffer;
      final float = ByteData.view(buffer).getFloat32(0, Endian.little);

      switch (uuid.toUpperCase()) {
        case 'ACDEB138-3BD0-4BB3-B159-19F6F70871ED': // SOC
          return '${float.toStringAsFixed(1)}%';
        case 'AC0768DF-2F49-43D4-B23D-1DC82C90A9E9': // Voltage
          return '${float.toStringAsFixed(1)}V';
        case '6FEEC926-BA3C-4E65-BC71-5DB481811186': // Current
          return '${float.toStringAsFixed(1)}A';
        case '9DEA1343-434F-4555-A0A1-BB43FCBC68A6': // Power
          return '${float.toStringAsFixed(1)}W';
        case '49267B41-560F-4CFF-ADC8-90EF85D2BE20': // High Cell
        case 'B9D01E5C-3751-4092-8B06-6D1FFF479E77': // Low Cell
          return '${float.toStringAsFixed(3)}V';
        case '0EA08B6D-C905-4D9D-93F8-51E35DA096FC': // High Temp
        case '26CD6E8A-175D-4C8E-B487-DEFF0B034F2A': // Low Temp
          return '${float.toStringAsFixed(1)}°C';
        case '396C768B-F348-44CC-9D46-92388F25A557': // Failure Level
          return float.toStringAsFixed(0);
        case '1C45825B-7C81-430B-8D5F-B644FFFC71BB': // Voltage Diff
          return '${float.toStringAsFixed(3)}V';
        default:
          return float.toStringAsFixed(2);
      }
    } catch (e) {
      debugPrint('Error converting value: $e');
      return 'Error';
    }
  }

  Future<void> _refreshCharacteristics() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      for (BluetoothCharacteristic c in widget.service.characteristics) {
        if (c.properties.read) {
          final value = await c.read();
          if (mounted) {
            setState(() => _characteristicValues[c.uuid.str] = value);
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Battery Management System')),
      body: widget.service.characteristics.isEmpty
        ? const Center(child: Text('No characteristics available'))
        : ListView.builder(
            itemCount: widget.service.characteristics.length,
            itemBuilder: (context, index) {
              final characteristic = widget.service.characteristics[index];
              final uuid = characteristic.uuid.str.toUpperCase();
              final name = uuidToName[uuid] ?? 'Unknown ($uuid)';

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(name),
                  subtitle: Text(
                    _getCharacteristicDisplayValue(
                      uuid,
                      _characteristicValues[characteristic.uuid.str],
                    ),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isRefreshing ? null : _refreshCharacteristics,
        child: _isRefreshing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              )
            : const Icon(Icons.refresh),
      ),
    );
  }
}

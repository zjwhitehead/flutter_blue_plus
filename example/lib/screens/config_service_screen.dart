import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ConfigServiceScreen extends StatefulWidget {
  final BluetoothService service;

  const ConfigServiceScreen({Key? key, required this.service}) : super(key: key);

  @override
  State<ConfigServiceScreen> createState() => _ConfigServiceScreenState();
}

class _ConfigServiceScreenState extends State<ConfigServiceScreen> {
  // Constants
  static const Map<String, String> uuidToName = {
    '58B29259-43EF-4593-B700-250EC839A2B2': 'Armed Time',
    '9CBAB736-3705-4ECF-8086-FB7C5FB86282': 'Screen Rotation',
    'DB47E20E-D8C1-405A-971A-DA0A2DF7E0F6': 'Sea Pressure',
    'D4962473-A3FB-4754-AD6A-90B079C3FB38': 'Metric Temperature',
    'DF63F19E-7295-4A44-A0DC-184D1AFEDDF7': 'Metric Altitude',
    'D76C2E92-3547-4F5F-AFB4-515C5C08B06B': 'Performance Mode',
    '4D076617-DC8C-46A5-902B-3F44FA28887E': 'Battery Size',
    'AD0E4309-1EB2-461A-B36C-697B2E1604D2': 'Theme',
    '50AB3859-9FBF-4D30-BF97-2516EE632FAD': 'Throttle Value',
    '2A27': 'Hardware Revision',
    '2A26': 'Firmware Version',
  };

  // State variables
  final Map<String, Stream<List<int>>> _characteristicStreams = {};
  final Map<String, List<int>> _characteristicValues = {};
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _setupCharacteristicStreams();
  }

  // Initialization methods
  void _setupCharacteristicStreams() {
    if (widget.service.characteristics.isEmpty) {
      debugPrint('No characteristics found for this service');
      return;
    }

    for (BluetoothCharacteristic c in widget.service.characteristics) {
      try {
        _characteristicStreams[c.uuid.str] = c.lastValueStream;
        _characteristicStreams[c.uuid.str]?.listen(
          (value) {
            if (mounted) {
              setState(() {
                _characteristicValues[c.uuid.str] = value;
              });
            }
          },
          onError: (error) {
            debugPrint('Error listening to characteristic ${c.uuid.str}: $error');
          },
        );

        // Auto-subscribe to throttle value notifications
        if (c.uuid.str.toUpperCase() == '50AB3859-9FBF-4D30-BF97-2516EE632FAD') {
          if (c.properties.notify) {
            c.setNotifyValue(true).then((_) {
              debugPrint('Successfully subscribed to throttle value notifications');
            }).catchError((error) {
              debugPrint('Failed to subscribe to throttle value notifications: $error');
            });
          }
        }

        // Initial read if the characteristic supports it
        if (c.properties.read) {
          c.read().then((value) {
            if (mounted) {
              setState(() {
                _characteristicValues[c.uuid.str] = value;
              });
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

  // Helper methods
  String _getCharacteristicDisplayValue(String uuid, List<int>? value) {
    if (value == null || value.isEmpty) return 'No value';

    switch (uuid.toUpperCase()) {
      case '2A26': return String.fromCharCodes(value);
      case '2A27': return value[0].toString();
      case '58B29259-43EF-4593-B700-250EC839A2B2': return '${value[0]} minutes';
      case '9CBAB736-3705-4ECF-8086-FB7C5FB86282': return value[0] == 1 ? 'Enabled' : 'Disabled';
      case 'DB47E20E-D8C1-405A-971A-DA0A2DF7E0F6': return '${value[0]} hPa';
      case 'D4962473-A3FB-4754-AD6A-90B079C3FB38': return value[0] == 1 ? 'Celsius' : 'Fahrenheit';
      case 'DF63F19E-7295-4A44-A0DC-184D1AFEDDF7': return value[0] == 1 ? 'True' : 'False';
      case 'D76C2E92-3547-4F5F-AFB4-515C5C08B06B': return value[0] == 1 ? 'Enabled' : 'Disabled';
      case '4D076617-DC8C-46A5-902B-3F44FA28887E': return '${value[0]} mAh';
      case 'AD0E4309-1EB2-461A-B36C-697B2E1604D2': return value[0] == 1 ? 'Dark' : 'Light';
      case '50AB3859-9FBF-4D30-BF97-2516EE632FAD':
        try {
          return '${(value[0] / 255 * 100).toStringAsFixed(1)}%';
        } catch (e) {
          return 'Invalid value';
        }
      default: return value.toString();
    }
  }

  Future<void> _refreshCharacteristics() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      for (BluetoothCharacteristic c in widget.service.characteristics) {
        try {
          final value = await c.read();
          setState(() => _characteristicValues[c.uuid.str] = value);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error reading characteristic: $e')),
            );
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // UI building methods
  Widget _buildCharacteristicValue(BluetoothCharacteristic characteristic, String value) {
    final uuid = characteristic.uuid.str.toUpperCase();

    switch (uuid) {
      case 'DF63F19E-7295-4A44-A0DC-184D1AFEDDF7': // Metric Altitude
      case 'D76C2E92-3547-4F5F-AFB4-515C5C08B06B': // Performance Mode
        bool currentValue = _characteristicValues[characteristic.uuid.str]?[0] == 1;
        return _buildSwitchRow(value, currentValue, characteristic);

      case '9CBAB736-3705-4ECF-8086-FB7C5FB86282': // Screen Rotation
        bool isRight = _characteristicValues[characteristic.uuid.str]?[0] == 1;
        return _buildRotationSelector(isRight, characteristic);

      case '50AB3859-9FBF-4D30-BF97-2516EE632FAD': // Throttle Value
        return _buildThrottleIndicator(characteristic);

      default:
        return Text(value);
    }
  }

  Widget _buildSwitchRow(String value, bool currentValue, BluetoothCharacteristic characteristic) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(value),
        Switch(
          value: currentValue,
          onChanged: (bool newValue) async {
            try {
              await characteristic.write(
                [newValue ? 1 : 0],
                withoutResponse: characteristic.properties.writeWithoutResponse
              );
              await characteristic.read();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating value: $e')),
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildRotationSelector(bool isRight, BluetoothCharacteristic characteristic) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(value: false, label: Text('Left')),
            ButtonSegment<bool>(value: true, label: Text('Right')),
          ],
          selected: {isRight},
          onSelectionChanged: (Set<bool> newSelection) async {
            try {
              bool newValue = newSelection.first;
              await characteristic.write(
                [newValue ? 1 : 0],
                withoutResponse: characteristic.properties.writeWithoutResponse
              );
              await characteristic.read();
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating value: $e')),
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildThrottleIndicator(BluetoothCharacteristic characteristic) {
    final value = _characteristicValues[characteristic.uuid.str]?[0];
    if (value == null) {
      return const Text('No value available');
    }

    try {
      final percentage = value / 255.0;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(percentage * 100).toStringAsFixed(1)}%'),
              Text('$value/255'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 10,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage > 0.9  // Red zone starts at 90%
                  ? Colors.red
                  : Colors.green,
              ),
            ),
          ),
        ],
      );
    } catch (e) {
      debugPrint('Error building throttle indicator: $e');
      return const Text('Error displaying value');
    }
  }

  Widget _buildVersionCard(BluetoothCharacteristic? firmwareChar, BluetoothCharacteristic? hardwareChar) {
    if (firmwareChar == null || hardwareChar == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Firmware Version'),
                  _buildCharacteristicValue(
                    firmwareChar,
                    _getCharacteristicDisplayValue(
                      firmwareChar.uuid.str,
                      _characteristicValues[firmwareChar.uuid.str],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hardware Revision'),
                  _buildCharacteristicValue(
                    hardwareChar,
                    _getCharacteristicDisplayValue(
                      hardwareChar.uuid.str,
                      _characteristicValues[hardwareChar.uuid.str],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Safely find firmware and hardware characteristics
    final firmwareChar = widget.service.characteristics
        .where((c) => c.uuid.str.toUpperCase() == '2A26')
        .firstOrNull;
    final hardwareChar = widget.service.characteristics
        .where((c) => c.uuid.str.toUpperCase() == '2A27')
        .firstOrNull;

    final otherCharacteristics = widget.service.characteristics
        .where((c) => c.uuid.str.toUpperCase() != '2A26' && c.uuid.str.toUpperCase() != '2A27')
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Config Service')),
      body: widget.service.characteristics.isEmpty
        ? const Center(child: Text('No characteristics available'))
        : ListView(
            children: [
              if (firmwareChar != null && hardwareChar != null)
                _buildVersionCard(firmwareChar, hardwareChar),
              ...otherCharacteristics.map((characteristic) {
                final uuid = characteristic.uuid.str.toUpperCase();
                final name = uuidToName[uuid] ?? 'Unknown ($uuid)';

                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(name),
                    subtitle: _buildCharacteristicValue(
                      characteristic,
                      _getCharacteristicDisplayValue(
                        characteristic.uuid.str,
                        _characteristicValues[characteristic.uuid.str],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
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

  @override
  void dispose() {
    // Unsubscribe from throttle value notifications
    final throttleChar = widget.service.characteristics
        .where((c) => c.uuid.str.toUpperCase() == '50AB3859-9FBF-4D30-BF97-2516EE632FAD')
        .firstOrNull;

    if (throttleChar != null && throttleChar.properties.notify) {
      throttleChar.setNotifyValue(false).then((_) {
        debugPrint('Successfully unsubscribed from throttle value notifications');
      }).catchError((error) {
        debugPrint('Failed to unsubscribe from throttle value notifications: $error');
      });
    }

    super.dispose();
  }
}

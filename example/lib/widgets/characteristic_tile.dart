import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import "../utils/snackbar.dart";

import "descriptor_tile.dart";

class CharacteristicTile extends StatefulWidget {
  final BluetoothCharacteristic characteristic;
  final List<DescriptorTile> descriptorTiles;

  const CharacteristicTile({Key? key, required this.characteristic, required this.descriptorTiles}) : super(key: key);

  @override
  State<CharacteristicTile> createState() => _CharacteristicTileState();
}

class _CharacteristicTileState extends State<CharacteristicTile> {
  List<int> _value = [];
  double _progressValue = 0.0;

  late StreamSubscription<List<int>> _lastValueSubscription;

  @override
  void initState() {
    super.initState();
    _lastValueSubscription = widget.characteristic.lastValueStream.listen((value) {
      _value = value;
      if (_value.isNotEmpty) {
        _progressValue = _value[0] / 255.0;
      }
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _lastValueSubscription.cancel();
    super.dispose();
  }

  BluetoothCharacteristic get c => widget.characteristic;

  List<int> _getRandomBytes() {
    final math = Random();
    return [math.nextInt(255), math.nextInt(255), math.nextInt(255), math.nextInt(255)];
  }

  Future onReadPressed() async {
    try {
      await c.read();
      Snackbar.show(ABC.c, "Read: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Read Error:", e), success: false);
    }
  }

  Future onWriteSpecificValue(int value) async {
    try {
      await c.write([value], withoutResponse: c.properties.writeWithoutResponse);
      Snackbar.show(ABC.c, "Write: Success", success: true);
      if (c.properties.read) {
        await c.read();
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Write Error:", e), success: false);
    }
  }

  Widget buildWriteButtons(BuildContext context) {
    bool withoutResp = widget.characteristic.properties.writeWithoutResponse;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          child: const Text('True'),
          onPressed: () async {
            await onWriteSpecificValue(1);
            if (mounted) {
              setState(() {});
            }
          }
        ),
        TextButton(
          child: const Text('False'),
          onPressed: () async {
            await onWriteSpecificValue(0);
            if (mounted) {
              setState(() {});
            }
          }
        ),
      ],
    );
  }

  Future onSubscribePressed() async {
    try {
      String op = c.isNotifying == false ? "Subscribe" : "Unubscribe";
      await c.setNotifyValue(c.isNotifying == false);
      Snackbar.show(ABC.c, "$op : Success", success: true);
      if (c.properties.read) {
        await c.read();
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Subscribe Error:", e), success: false);
    }
  }

  static const Map<String, String> uuidToName = {
    'DF63F19E-7295-4A44-A0DC-184D1AFEDDF7': 'Metric Alt',
    '2A26': 'FW Version',
    '58B29259-43EF-4593-B700-250EC839A2B2': 'Armed Time',
    '9CBAB736-3705-4ECF-8086-FB7C5FB86282': 'Screen Rotation',
    'DB47E20E-D8C1-405A-971A-DA0A2DF7E0F6': 'Sea Pressure',
    'D4962473-A3FB-4754-AD6A-90B079C3FB38': 'Metric Temp',
    'D76C2E92-3547-4F5F-AFB4-515C5C08B06B': 'Performance Mode',
    '4D076617-DC8C-46A5-902B-3F44FA28887E': 'Battery Size',
    'AD0E4309-1EB2-461A-B36C-697B2E1604D2': 'Theme',
    '50AB3859-9FBF-4D30-BF97-2516EE632FAD': 'Throttle Value',
    '2A27': 'HW Revision',
  };

  Widget buildUuid(BuildContext context) {
    String uuid = '0x${widget.characteristic.uuid.str.toUpperCase()}';
    String? name = uuidToName[widget.characteristic.uuid.str.toUpperCase()];
    return name != null
      ? RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13),
            children: [
              TextSpan(
                text: '$name\n',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: uuid,
                style: const TextStyle(color: Colors.black),
              ),
            ],
          ),
        )
      : Text(uuid, style: const TextStyle(fontSize: 13));
  }

  Widget buildValue(BuildContext context) {
    String data = _value.toString();
    return Text(data, style: TextStyle(fontSize: 13, color: Colors.grey));
  }

  Widget buildReadButton(BuildContext context) {
    return TextButton(
        child: Text("Read"),
        onPressed: () async {
          await onReadPressed();
          if (mounted) {
            setState(() {});
          }
        });
  }

  Widget buildSubscribeButton(BuildContext context) {
    bool isNotifying = widget.characteristic.isNotifying;
    return TextButton(
        child: Text(isNotifying ? "Unsubscribe" : "Subscribe"),
        onPressed: () async {
          await onSubscribePressed();
          if (mounted) {
            setState(() {});
          }
        });
  }

  Widget buildButtonRow(BuildContext context) {
    bool read = widget.characteristic.properties.read;
    bool write = widget.characteristic.properties.write;
    bool notify = widget.characteristic.properties.notify;
    bool indicate = widget.characteristic.properties.indicate;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (read) buildReadButton(context),
        if (write) buildWriteButtons(context),
        if (notify || indicate) buildSubscribeButton(context),
      ],
    );
  }

  Widget buildProgressBar(BuildContext context) {
    if (widget.characteristic.uuid.str.toUpperCase() != '50AB3859-9FBF-4D30-BF97-2516EE632FAD') {
      return const SizedBox.shrink();
    }

    return Slider(
      value: _progressValue,
      min: 0.0,
      max: 1.0,
      onChanged: (value) {
        // This can be left empty as the slider is updated by the stream
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isThrottleValue = widget.characteristic.uuid.str.toUpperCase() == '50AB3859-9FBF-4D30-BF97-2516EE632FAD';

    return ExpansionTile(
      title: ListTile(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Characteristic'),
            buildUuid(context),
            buildValue(context),
            if (isThrottleValue) buildProgressBar(context),
          ],
        ),
        subtitle: buildButtonRow(context),
        contentPadding: const EdgeInsets.all(0.0),
      ),
      children: widget.descriptorTiles,
    );
  }
}

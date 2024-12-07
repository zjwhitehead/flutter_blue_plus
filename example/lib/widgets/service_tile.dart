import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import "characteristic_tile.dart";
import "../screens/config_service_screen.dart";
import "../screens/bms_service_screen.dart";

class ServiceTile extends StatelessWidget {
  final BluetoothService service;
  final List<CharacteristicTile> characteristicTiles;

  const ServiceTile({Key? key, required this.service, required this.characteristicTiles}) : super(key: key);

  static const Map<String, String> uuidToName = {
    '1779A55B-DEB8-4482-A5D1-A12E62146138': 'Config Service',
    '9E0F2FA3-3F2B-49C0-A6A3-3D8923062133': 'BMS Telemetry Service',
    'C154DAE9-1984-40EA-B20F-5B23F9CBA0A9': 'ESC Telemetry Service',
  };

  Widget buildUuid(BuildContext context) {
    String uuid = '0x${service.uuid.str.toUpperCase()}';
    String? name = uuidToName[service.uuid.str.toUpperCase()];
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

  @override
  Widget build(BuildContext context) {
    String upperUuid = service.uuid.str.toUpperCase();
    bool isConfigService = upperUuid == '1779A55B-DEB8-4482-A5D1-A12E62146138';
    bool isBMSService = upperUuid == '9E0F2FA3-3F2B-49C0-A6A3-3D8923062133';

    if (isConfigService || isBMSService) {
      return ListTile(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Service', style: TextStyle(color: Colors.blue)),
            buildUuid(context),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => isConfigService
                ? ConfigServiceScreen(service: service)
                : BMSServiceScreen(service: service),
            ),
          );
        },
      );
    }

    return characteristicTiles.isNotEmpty
      ? ExpansionTile(
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Service', style: TextStyle(color: Colors.blue)),
              buildUuid(context),
            ],
          ),
          children: characteristicTiles,
        )
      : ListTile(
          title: const Text('Service'),
          subtitle: buildUuid(context),
        );
  }
}

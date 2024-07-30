import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'speed_unit.dart';

class SpeedPage extends StatefulWidget {
  final Function(double) onSpeedUpdate;

  const SpeedPage({Key? key, required this.onSpeedUpdate}) : super(key: key);

  @override
  State<SpeedPage> createState() => _SpeedPageState();
}

class _SpeedPageState extends State<SpeedPage> {
  bool locationDisabled = false;
  double currentSpeed = 0.0;
  SpeedUnit speedUnit = SpeedUnit.KPH;

  @override
  void initState() {
    super.initState();
    startMeasurement();
  }

  void startMeasurement() {
    checkPermission();

    var options = const LocationSettings(
        accuracy: LocationAccuracy.best, distanceFilter: 0);
    Geolocator.getPositionStream(locationSettings: options).listen((position) {
      setPosition(position);
    });
  }

  void setPosition(Position position) {
    setState(() {
      currentSpeed = position.speed;
    });
    widget.onSpeedUpdate(currentSpeed);
  }

  void checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        locationDisabled = true;
      });
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          locationDisabled = true;
        });
      }
    }

    if (permission == LocationPermission.deniedForever) {
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }

    setState(() {
      locationDisabled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return locationDisabled
        ? ElevatedButton(
        onPressed: startMeasurement, child: const Text('Retry'))
        : SizedBox.shrink(); // Empty widget when speed is being updated
  }
}
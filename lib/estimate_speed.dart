import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'speed_unit.dart';

class SpeedPage extends StatefulWidget {
  final Function(double) onSpeedUpdate;

  const SpeedPage({Key? key, required this.onSpeedUpdate}) : super(key: key);

  @override
  State<SpeedPage> createState() => SpeedPageState();
}

class SpeedPageState extends State<SpeedPage> {
  bool locationDisabled = false;
  double currentSpeed = 0.0;
  SpeedUnit speedUnit = SpeedUnit.KPH;
  StreamSubscription<Position>? positionStream;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    checkPermission();
  }

  void startMeasurement() {
    print("start measurement");
    var options = const LocationSettings(
        accuracy: LocationAccuracy.best, distanceFilter: 0,);
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        positionStream = Geolocator.getPositionStream(locationSettings: options).listen((position) {
          setPosition(position);
        });
      });
    });

  }

  void stopMeasurement() {
    _timer?.cancel();
    positionStream?.cancel();
  }

  void setPosition(Position position) {
    setState(() {
      print('loc get');
      currentSpeed = position.speed;
    });
    widget.onSpeedUpdate(currentSpeed);
  }

  Future<void> checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('location disabled');
      setState(() {
        locationDisabled = true;
      });
      return;
    }

    if (serviceEnabled) {
      print('location enable');
      setState(() {
        locationDisabled = false;
      });
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      print('location denied check');
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('location denied request');
        setState(() {
          locationDisabled = true;
        });
        _showPermissionDeniedDialog(); // 提示用户权限被拒绝
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        locationDisabled = true;
      });
      return;
    }

    setState(() {
      locationDisabled = false;
    });
  }
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Location Permission Denied"),
        content: Text("Please grant location permissions to use this feature."),
        actions: [
          TextButton(
            child: Text("OK"),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    stopMeasurement();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return locationDisabled
        ? ElevatedButton(
      onPressed: () async {
        await checkPermission();
        if (!locationDisabled) {
          startMeasurement();
        }
      },
      child: const Text('Retry'),
    )
        : Container(); // Display nothing or other content when permission is granted
  }
}
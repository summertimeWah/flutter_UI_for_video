import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'camera_page.dart';
import 'estimate_speed.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video and Speed App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isRecording = false;
  double currentSpeed = 0.0;
  final GlobalKey<SpeedPageState> _speedPageKey = GlobalKey<SpeedPageState>();

  @override
  void initState() {
    super.initState();
    // _checkAndRequestInitCamera();
    // _checkAndRequestLocationPermission();
  }

  Future<void> _checkAndRequestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      // 已獲得權限，可以進行位置操作
      print('Location permission granted');
    } else {
      // 權限被拒絕
      _showPermissionDeniedDialog();
      print('Location permission denied');
    }
  }

  Future<void> _checkAndRequestInitCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
    );
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


  void toggleRecording() {

    _checkAndRequestLocationPermission();
    setState(() {
      isRecording = !isRecording;
    });

    print("start measurement for first stage");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final speedPageState = _speedPageKey.currentState;
      if (isRecording) {
        if (speedPageState != null) {
          speedPageState.startMeasurement();
        }
        else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text("Error"),
              content: Text("SpeedPage is not ready. Please try again later."),
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
      }
      else {
        speedPageState?.stopMeasurement();
      }
    });
  }


  void updateSpeed(double speed) {
    setState(() {
      currentSpeed = speed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CameraPage(
            toggleRecording: toggleRecording,
            isRecording: isRecording,
            currentSpeed: currentSpeed,
          ),
          if (isRecording)
            SpeedPage(
              key: _speedPageKey,
              onSpeedUpdate: updateSpeed,
            ),
        ],
      ),
    );
  }
}

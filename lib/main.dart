import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_for_yolov7/speed_unit.dart';
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
  String currentSpeed = "0.0 km/h";
  final GlobalKey<SpeedPageState> _speedPageKey = GlobalKey<SpeedPageState>();

  SpeedUnit speedUnit = SpeedUnit.KPH;

  @override
  void initState() {
    super.initState();

  }


  void toggleRecording() {
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
      currentSpeed = speedUnit.format(speed);  // 使用 SpeedUnit 格式化速度
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

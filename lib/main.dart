import 'package:flutter/material.dart';
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

  void toggleRecording() {
    setState(() {
      isRecording = !isRecording;
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
              onSpeedUpdate: updateSpeed,
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'api_service.dart';

class CameraPage extends StatefulWidget {
  final bool isRecording;
  final Function toggleRecording;
  final String currentSpeed;

  const CameraPage({
    Key? key,
    required this.isRecording,
    required this.toggleRecording,
    required this.currentSpeed,
  }) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ApiService _apiService = ApiService();
  late RTCVideoRenderer _localRenderer;
  bool _isInitialized = false;
  int _recordedSeconds = 0;
  int _dangerLevel = 1;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _localRenderer = RTCVideoRenderer();
    await _localRenderer.initialize();
    print("Renderer initialized.");

    await _apiService.initializeConnection();
    print("Connection initialized.");

    final mediaConstraints = {
      'audio': false,
      'video': {
        'facingMode': 'environment',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
        'frameRate': {'ideal': 30},
      },
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    print("MediaStream obtained: ${stream.id}");
    _localRenderer.srcObject = stream;

    setState(() {
      _isInitialized = true;
      _isLoading = false;
    });
    print("Camera view initialized successfully.");

    if (widget.isRecording) {
      _startRecordingTimer();
    }
  }

  void _startRecordingTimer() {
    _recordedSeconds = 0;
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (widget.isRecording) {
        setState(() {
          _recordedSeconds++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _apiService.closeConnection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    Color? borderColor;
    String? warningText;

    if (widget.isRecording) {
      switch (_dangerLevel) {
        case 4:
          borderColor = Colors.red;
          warningText = "Caution!!";
          break;
        case 3:
          borderColor = Colors.orange;
          warningText = "Front";
          break;
        case 2:
          borderColor = Colors.yellow;
          warningText = "Others";
          break;
        case 1:
        default:
          borderColor = null;
          warningText = null;
          break;
      }
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              border: borderColor != null ? Border.all(color: borderColor!, width: 5) : null,
            ),
            child: RTCVideoView(_localRenderer),
          ),
        ),
        if (warningText != null)
          Positioned(
            top: 25,
            child: Container(
              padding: EdgeInsets.all(8.0),
              color: borderColor!.withOpacity(0.5),
              child: Text(
                warningText!,
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        Positioned(
          bottom: 25,
          child: GestureDetector(
            onTap: () {
              widget.toggleRecording();
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
                widget.isRecording
                    ? Icon(Icons.stop, color: Colors.red, size: 50)
                    : Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.isRecording)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(8.0),
              color: Colors.black54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.currentSpeed}',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  Text(
                    'Recording: $_recordedSeconds s',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

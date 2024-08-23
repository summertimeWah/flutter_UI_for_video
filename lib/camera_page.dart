import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:video_for_yolov7/video_show/video_page.dart';
import 'api_service.dart';
import 'estimate_speed.dart';
import 'firebase_storage_page.dart';
import 'package:path/path.dart' show basename;


class CameraPage extends StatefulWidget {
  final bool isRecording;
  final void Function() toggleRecording;
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
  bool _isLoading = true;
  late CameraController _cameraController;

  int _recordedSeconds = 0;
  Timer? _timer;

  int _dangerLevel = 0; // Variable to store the danger level (1-4)
  final ApiService _apiService = ApiService(); // ApiService instance to send frames


  @override
  void initState() {
    super.initState();
    _initCamera();
    _recordedSeconds = 0;
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    _cameraController = CameraController(backCamera, ResolutionPreset.max);
    await _cameraController.initialize();
    setState(() => _isLoading = false);

    _checkAndRequestLocationPermission();
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
    return;
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

  Future<void> _captureAndSendFrame() async {
    try {
      print("this is dangerLevel");
      final frame = await _cameraController.takePicture(); // Capture a frame
      Uint8List frameData = await File(frame.path).readAsBytes(); // Read as bytes

      // Send frame to server and get danger level
      int dangerLevel = await _apiService.sendFrame(frameData);

      setState(() {
        _dangerLevel = dangerLevel; // Update UI with danger level
      });
    } catch (e) {
      print("Error capturing frame: $e");
    }
  }


  Future<void> _recordVideo() async {
    var currentUser = FirebaseAuth.instance.currentUser;

    if (widget.isRecording) {
      // 停止錄影並取得影片檔案
      final file = await _cameraController.stopVideoRecording();
      widget.toggleRecording();
      _timer?.cancel();

      try {
        // 讀取影片檔案為 Uint8List
        Uint8List videoBytes = await File(file.path).readAsBytes();

        // 獲取當前時間並格式化
        String formattedTime = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

        var userid = currentUser!.uid;

        // 處理檔案名稱，去掉 .temp 並加上錄製時間
        String fileName = 'REC_$formattedTime.mp4';
        String? userID = userid;
        print("檔名:$fileName");

        // 上傳影片到 Firebase Storage
        await FirebaseStoragePage.uploadObject(userID, fileName, videoBytes);

        // 上傳成功提示
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("影片已成功上傳至 Firebase Storage"))
        );
      } catch (e) {
        print("上傳失敗: $e");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("上傳失敗: $e"))
        );
      }
    } else {
      // 開始錄影
      await _cameraController.prepareForVideoRecording();
      await _cameraController.startVideoRecording();
      widget.toggleRecording();
      _recordedSeconds = 0;
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _recordedSeconds++;
        });
      });
      // Timer for capturing frames at 30 fps (every 33ms)
      Timer.periodic(Duration(milliseconds: 33), (timer) {
        if (!widget.isRecording) {
          timer.cancel(); // Stop frame capture if recording is stopped
        } else {
          print("this is dangerLevel");
          _captureAndSendFrame(); // Capture and send a frame every 33ms (approx 30 fps)
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else {
      // Determine border color and text based on danger level
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
          // Camera preview
          Positioned.fill(
            child: Container(
                decoration: BoxDecoration(
                  border: borderColor != null ? Border.all(color: borderColor!, width: 5) : null, // Red border if danger level is 4
                ),
            child: CameraPreview(_cameraController),
            ),
          ),
          // Warning text display based on danger level
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
          // Record button with a circle and dot inside
          Positioned(
            bottom: 25,
            child: GestureDetector(
              onTap: _recordVideo,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // White circle
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                  // Red dot or stop icon inside
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
          // Speed overlay
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

}
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_for_yolov7/video_page.dart';
import 'estimate_speed.dart';


class CameraPage extends StatefulWidget {
  final bool isRecording;
  final void Function() toggleRecording;
  final double currentSpeed;

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

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    _cameraController = CameraController(frontCamera, ResolutionPreset.max);
    await _cameraController.initialize();
    setState(() => _isLoading = false);
  }

  Future<void> _recordVideo() async {
    if (widget.isRecording) {
      final file = await _cameraController.stopVideoRecording();
      widget.toggleRecording();
      final route = MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VideoPage(filePath: file.path),
      );
      Navigator.push(context, route);
    } else {
      await _cameraController.prepareForVideoRecording();
      await _cameraController.startVideoRecording();
      widget.toggleRecording();
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
      return Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Camera preview
          Positioned.fill(
            child: CameraPreview(_cameraController),
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
                child: Text(
                  '${widget.currentSpeed.toStringAsFixed(2)} m/s',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
            ),
        ],
      );
    }
  }
}
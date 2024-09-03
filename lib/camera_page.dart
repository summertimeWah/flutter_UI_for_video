import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

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
  late CameraController _cameraController;
  Timer? _recordingTimer;
  Timer? _frameTimer;
  bool isSendingFrames = false;

  bool _isInitialized = false;
  int _recordedSeconds = 0;
  int _dangerLevel = 1;
  bool _isLoading = true;

  final ApiService _apiService = ApiService();

  int width = 0;
  int height = 0;
  Uint8List? _nv21DataCache; // 缓存对象用于重用

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
    );

    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController.initialize();
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });

      if (widget.isRecording) {
        _startImageStream();
        _startRecordingTimer();
      }
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        _isLoading = false;
      });
    }

    final size = _cameraController.value.previewSize;
    if (size != null) {
      width = size.width.toInt();
      height = size.height.toInt();
      _nv21DataCache = Uint8List(width * height + (width ~/ 2) * (height ~/ 2) * 2);
    }
  }

  void _startImageStream() async {
    if (!_cameraController.value.isStreamingImages) {
      try {
        _apiService.initializeConnection((int dangerLevel) {
          if (mounted) {
            setState(() {
              _dangerLevel = dangerLevel;
            });
          }
        });

        await _cameraController.startImageStream((CameraImage image) {
          if (_frameTimer == null || !_frameTimer!.isActive) {
            _frameTimer = Timer(Duration(milliseconds: 33), () {
              if (widget.isRecording) {
                _processAndSendFrame(image);
              }
            });
          }
        });
      } catch (e) {
        print("启动图像流时发生错误: $e");
      }
    } else {
      print("图像流已经在运行中");
    }
  }


  void _processAndSendFrame(CameraImage image) {
    if (image.format.group == ImageFormatGroup.yuv420) {
      _convertYUV420ToNV21(image);
      if (_nv21DataCache != null) {
        String base64Frame = base64Encode(_nv21DataCache!);
        _apiService.sendFrame(base64Frame, width, height);
      }
    } else {
      print('Unsupported image format');
    }
  }

  void _convertYUV420ToNV21(CameraImage image) {
    if (_nv21DataCache == null) return;

    int ySize = width * height;
    int uvSize = (width ~/ 2) * (height ~/ 2);

    // 重用已分配的内存，避免重复分配
    _nv21DataCache!.setRange(0, ySize, image.planes[0].bytes);

    int index = ySize;
    for (int i = 0; i < uvSize; i++) {
      _nv21DataCache![index++] = image.planes[2].bytes[i]; // V平面
      _nv21DataCache![index++] = image.planes[1].bytes[i]; // U平面
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordedSeconds = 0;
    _recordingTimer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
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
  void didUpdateWidget(covariant CameraPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _startImageStream();
        _startRecordingTimer();
      } else {
        _cameraController.stopImageStream();
        _recordingTimer?.cancel();
        _apiService.closeConnection();
      }
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _recordingTimer?.cancel();
    _apiService.closeConnection();
    super.dispose();
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
              child: CameraPreview(_cameraController),
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
}

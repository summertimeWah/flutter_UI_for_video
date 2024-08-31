import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
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

  Process? _ffmpegProcess;
  String _ffmpegCommand = "";

// Declare pipe as a global variable
  late String? pipe;

  @override
  void initState() {
    super.initState();
    print("init here");
    _initCamera();
    _apiService.initializeConnection((int dangerLevel) {
      setState(() {
        _dangerLevel = dangerLevel; // Update danger level
      });
    });
    _recordedSeconds = 0;
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _timer?.cancel();
    _ffmpegProcess?.kill(); // 停止 FFmpeg 處理
    super.dispose();
  }


  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    _cameraController = CameraController(backCamera, ResolutionPreset.max);

    await _cameraController.initialize();

    // 獲取解析度
    final size = _cameraController.value.previewSize;
    if (size != null) {
      // 取得相機的解析度
      int width = size.width.toInt();
      int height = size.height.toInt();

      pipe = await FFmpegKitConfig.registerNewFFmpegPipe();
      print("print $pipe yeah");

      // 動態生成 FFmpeg 命令
      if (pipe != null) {
        String? pipeId = pipe;
        _ffmpegCommand = "-f rawvideo -vcodec rawvideo -s 640x480 -pix_fmt yuv420p -i - -f image2pipe -vcodec mjpeg pipe:1";

        // _ffmpegCommand = "-f rawvideo -pixel_format yuv420p -video_size ${width}x${height}"
        //     "-framerate 30 -i pipe:1 -vf fps=30 -f image2pipe -vcodec mjpeg -";
        //_ffmpegCommand = "-f rawvideo -pix_fmt yuv420p -s ${width}x${height} -r 30 -i $pipe -vf fps=30 -f rawvideo -pix_fmt nv21 pipe:1";
      } else {
        print("Error: pipe is null!");
      }

    }

    setState(() => _isLoading = false);
    _checkAndRequestLocationPermission();
  }

  void _startSendingFrames() async {
    print("開始影像串流...");

    // 加入延遲以確保狀態同步
    await Future.delayed(Duration(milliseconds: 100));

    // 檢查錄影狀態是否為正在錄製
    if (widget.isRecording) {
      // 檢查相機是否已經在影像串流中，避免重複啟動
      if (!_cameraController.value.isStreamingImages) {
        try {
          await _cameraController.startImageStream((CameraImage image) {
            print("影像串流回呼觸發");  // 這個印出可以幫助你確認回呼函數有沒有被調用

            // 確認是否還在錄影狀態中
            if (widget.isRecording) {
              print("錄影進行中，處理影像幀");
              _processAndSendFrame(image);
            } else {
              print("停止影像串流，因為已經不在錄影狀態");
              _cameraController.stopImageStream();  // 停止影像串流
            }
          });
        } catch (e) {
          print("啟動影像串流時發生錯誤: $e");
        }
      } else {
        print("影像串流已經在運行中");
      }
    } else {
      print("不在錄影狀態，無需啟動影像串流");
    }
  }


  // bool _isCapturing = false;
  //
  // void _processCameraImage(CameraImage image) {
  //   if (_isCapturing) {
  //     print('Previous capture still in progress...');
  //     return;
  //   }
  //
  //   _isCapturing = true;  // Set the flag to prevent new captures
  //
  //   try {
  //     print('Processing frame...');
  //     // Your existing image format handling logic here
  //     if (image.format.group == ImageFormatGroup.yuv420) {
  //       Uint8List nv21Data = _convertYUV420toNV21(image);
  //       _apiService.sendFrame(nv21Data);
  //     } else if (image.format.group == ImageFormatGroup.bgra8888) {
  //       Uint8List bgraData = _convertBGRA8888(image);
  //       _apiService.sendFrame(bgraData);
  //     } else {
  //       print('Unsupported image format');
  //     }
  //   } catch (e) {
  //     print('Error capturing frame: $e');
  //   } finally {
  //     _isCapturing = false;  // Reset the flag once done
  //   }
  // }

  void _processAndSendFrame(CameraImage image) {
    print("start process");
    if (image.format.group == ImageFormatGroup.yuv420) {
      Uint8List nv21Data = _convertRawBytesToNV21(image as Uint8List);

      // Convert to Base64 and send via WebSocket
      String base64Frame = base64Encode(nv21Data);
      _apiService.sendFrame(base64Frame); // Send as String, no need to cast
      print("ending calling");
    } else {
      print('Unsupported image format');
    }
  }

  Uint8List _convertRawBytesToNV21(Uint8List rawBytes) {
    int ySize = (rawBytes.length * 2) ~/ 3;
    int uvSize = rawBytes.length - ySize;

    // Allocate for Y + interleaved UV
    Uint8List nv21 = Uint8List(rawBytes.length);

    // Copy Y data
    nv21.setRange(0, ySize, rawBytes.sublist(0, ySize));

    // Interleave U and V planes into NV21 format
    int index = ySize;
    for (int i = 0; i < uvSize ~/ 2; i++) {
      nv21[index++] = rawBytes[ySize + i + uvSize ~/ 2]; // V plane
      nv21[index++] = rawBytes[ySize + i]; // U plane
    }

    return nv21;
  }


  Uint8List _convertBGRA8888(CameraImage image) {
    // Assuming that each pixel is 4 bytes (B, G, R, A)
    int length = image.planes[0].bytes.length;
    return Uint8List.fromList(image.planes[0].bytes);
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



  Future<void> _recordVideo() async {
    var currentUser = FirebaseAuth.instance.currentUser;

    if (widget.isRecording) {
      // 停止錄影並取得影片檔案
      final file = await _cameraController.stopVideoRecording();
      widget.toggleRecording();
      _timer?.cancel();

      try {

        if (_ffmpegProcess != null) {
          _ffmpegProcess!.kill();  // 停止 FFmpeg
        }

        // 讀取影片檔案為 Uint8List
        Uint8List videoBytes = await File(file.path).readAsBytes();

        // 獲取當前時間並格式化
        String formattedTime = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        var userid = currentUser!.uid;

        // 處理檔案名稱，去掉 .temp 並加上錄製時間
        String fileName = 'REC_$formattedTime.mp4';
        String? userID = userid;
        print("檔名: $fileName");

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

      // 確保停止影像串流
      if (_cameraController.value.isStreamingImages) {
        try {
          await _cameraController.stopImageStream();
          print("停止影像串流成功");
        } catch (e) {
          print("停止影像串流失敗: $e");
        }
      }
    } else {
      // 開始錄影
      await _cameraController.prepareForVideoRecording();
      await _cameraController.startVideoRecording();
      widget.toggleRecording();
      _recordedSeconds = 0;

      // 啟動影像串流
      _startSendingFrames();
      // _executeFFmpegCommand();

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _recordedSeconds++;
        });
      });
    }
  }


  void _startFFmpegStream() async {
    if (pipe != null) {
      print("開始");
      // Run FFmpeg with async execution for continuous streaming
      FFmpegKit.executeAsync(_ffmpegCommand, (session) async {
        print("success here");
        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          print("FFmpeg streaming successful");
          _sendFrameFromFFmpeg();
        } else {
          print("FFmpeg streaming failed with return code: $returnCode");
        }
      });
    } else {
      print("Pipe is not initialized");
    }
  }


  void _sendFrameFromFFmpeg() async {
    if (pipe != null) {
      print("pipe is not null");

      try {
        File ffmpegOutput = File(pipe!);
        // Set up an asynchronous stream for reading from FFmpeg's pipe output.
        Stream<List<int>> inputStream = ffmpegOutput.openRead();;//stdin.asBroadcastStream();
        print("just here please");

        await for (var bytes in inputStream) {
          if (bytes.isNotEmpty) {
            print("Data read successfully");

            Uint8List frameBytes = Uint8List.fromList(bytes);
            String base64Frame = base64Encode(frameBytes);
            _apiService.sendFrame(base64Frame);
            print("Frame sent successfully.");
          } else {
            print("No frame data available.");
          }
        }
      } catch (e) {
        print("Error reading from pipe: $e");
      }
    } else {
      print("Pipe is not initialized.");
    }
  }




  void _executeFFmpegCommand() {
    if (pipe != null) {
      print("Pipe is initialized. Executing FFmpeg command...");

      // 打印 FFmpeg 指令以便檢查
      String? pipeId = pipe;
      String ffmpegCommand = "-f rawvideo -pixel_format yuv420p -video_size 640x480 -framerate 30 -i pipe:$pipeId -vf fps=30 -f image2pipe -vcodec mjpeg -";


      // 啟用日誌回調以檢查 FFmpeg 日誌
      FFmpegKitConfig.enableLogCallback((log) {
        print("FFmpeg log: ${log.getMessage()}");
      });

      // 啟用統計回調以取得執行過程中的資訊
      FFmpegKitConfig.enableStatisticsCallback((statistics) {
        print("FFmpeg statistics: Time=${statistics.getTime()} ms");
      });

      // 執行 FFmpeg 指令
      FFmpegKit.executeAsync(ffmpegCommand, (session) async {
        final logs = await session.getAllLogs();
        logs.forEach((log) {
          print("FFmpeg log: ${log.getMessage()}");
        });

        final returnCode = await session.getReturnCode();
        if (ReturnCode.isSuccess(returnCode)) {
          print("FFmpeg streaming successful");

          // 在這裡添加處理流式幀數據的邏輯
          // 假設你能夠從 pipe 讀取幀數據，並發送到你的 API
          // api_service.sendFrame(frameData);
        } else {
          print("FFmpeg streaming failed with return code: $returnCode");
        }
      });

    } else {
      print("Pipe is not initialized");
    }
  }


// 測試簡單的 FFmpeg 指令以確認是否為指令複雜度問題
  void _executeSimpleFFmpegCommand() {
    String simpleCommand = "-version";

    FFmpegKit.executeAsync(simpleCommand, (session) async {
      print("Simple FFmpeg command executed.");

      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        print("Simple command successful");
      } else {
        print("Simple command failed with return code: $returnCode");
      }
    });
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
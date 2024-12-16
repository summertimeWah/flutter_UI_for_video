import 'dart:convert';
import 'dart:typed_data';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  static const String _webSocketUrl = 'wss://3956-2001-b400-e739-6f68-cd22-baf7-4cbc-a69f.ngrok-free.app/ws';


  late SocketChannel _socketChannel;

  ApiService() {
    // 初始化 WebSocket
    _socketChannel = SocketChannel(() => IOWebSocketChannel.connect(_webSocketUrl));
  }
  void initializeConnection(Function(double) onDataReceived) async {
    // 監聽 WebSocket
    _socketChannel.stream.listen(
          (event) {
        print('Received event: $event');
        try {
          var jsonResponse = jsonDecode(event);

          if (jsonResponse.containsKey('distance')) {
            // 處理 'danger'
            double distance = double.parse(jsonResponse['distance'].toString());
            print('Received danger level: $distance');
            onDataReceived(distance);

          } else if (jsonResponse.containsKey('status')) {
            // Assuming the server sends status codes
            String statusCode = jsonResponse['status'].toString();
            print('Received status: $statusCode');
          } else {
            print('Unexpected data format: $jsonResponse');
          }
        } catch (e) {
          print('Error parsing event data: $e');
        }
      },
      onError: (error) {
        print('Error: $error');
      },
      onDone: () {
        print('Connection closed');
      },
    );
  }


  void sendFrame(String base64Image, int frameWidth, int frameHeight) {
    print("already tring");
    try {
      // Frame is already in Base64 string format, no need to encode again
      Map<String, dynamic> message = {
        "type": "frame",
        "frame": base64Image,
        "width": frameWidth,
        "height": frameHeight,
      };

      // Send the message over WebSocket
      _socketChannel.sendMessage(jsonEncode(message));
      print('Frame sent successfully');
    } catch (e) {
      print('Error sending frame: $e');
    }
  }

  void sendRecordingStatus(bool isRecording, String userId) {
    try {
      Map<String, dynamic> message = {
        "type": "recording_status",
        "isRecording": isRecording,
        "userid": userId,
      };

      _socketChannel.sendMessage(jsonEncode(message));
      print('Recording status sent: $isRecording');
    } catch (e) {
      print('Error sending recording status: $e');
    }
  }




  void closeConnection() {
    _socketChannel.close();
  }
}

class SocketChannel {
  SocketChannel(this._getIOWebSocketChannel) {
    _startConnection();
  }

  final IOWebSocketChannel Function() _getIOWebSocketChannel;
  late IOWebSocketChannel _ioWebSocketChannel;
  WebSocketSink get _sink => _ioWebSocketChannel.sink;
  late Stream<dynamic> _innerStream;

  final _outerStreamSubject = BehaviorSubject<dynamic>();
  Stream<dynamic> get stream => _outerStreamSubject.stream;

  bool _isFirstRestart = false;
  bool _isFollowingRestart = false;
  bool _isManuallyClosed = false;

  void _handleLostConnection() {
    if (_isFirstRestart && !_isFollowingRestart) {
      Future.delayed(const Duration(seconds: 3), () {
        _isFollowingRestart = false;
        _startConnection();
      });
      _isFollowingRestart = true;
    } else {
      _isFirstRestart = true;
      _startConnection();
    }
  }

  void _startConnection() {
    _ioWebSocketChannel = _getIOWebSocketChannel();
    _innerStream = _ioWebSocketChannel.stream;
    _innerStream.listen(
          (event) {
        _isFirstRestart = false;
        _outerStreamSubject.add(event);
      },
      onError: (error) {
        _handleLostConnection();
      },
      onDone: () {
        if (!_isManuallyClosed) {
          _handleLostConnection();
        }
      },
    );
  }


  void sendMessage(String message) => _sink.add(message);

  void close() {
    _isManuallyClosed = true;
    _sink.close();
  }
}
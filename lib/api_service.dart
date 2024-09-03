import 'dart:convert';
import 'dart:typed_data';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ApiService {
  static const String _webSocketUrl = 'ws://10.0.2.2:8000/ws'; // 更新为 FastAPI 的 WebSocket 端点

  late SocketChannel _socketChannel;

  ApiService() {
    // 初始化 WebSocket 连接
    _socketChannel = SocketChannel(() => IOWebSocketChannel.connect(_webSocketUrl));
  }
  void initializeConnection(Function(int) onDataReceived) async {
    // 监听 WebSocket 数据流
    _socketChannel.stream.listen(
          (event) {
        print('Received event: $event');
        try {
          // 假设服务器返回的数据是一个包含状态的 JSON 格式字符串
          var jsonResponse = jsonDecode(event);

          if (jsonResponse.containsKey('danger')) {
            // 处理 'danger' 字段并将其转换为整数
            int dangerLevel = int.parse(jsonResponse['danger'].toString());
            print('Received danger level: $dangerLevel');
            // 你可以在这里调用一个函数来使用 dangerLevel 值
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

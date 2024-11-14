import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;

class ApiService {
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},  // STUN server
    ]
  };

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;

  Future<void> initializeConnection() async {
    try {
      _peerConnection = await createPeerConnection(_iceServers);

      if (_peerConnection == null) {
        print("Failed to create peer connection.");
      } else {
        print("Peer connection created successfully.");
      }

      _peerConnection!.onConnectionState = (state) {
        print('Connection state: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          print('Connection failed.');
        }
      };
      print('Connection state: $_peerConnection!.onConnectionState');

      final mediaConstraints = {
        'audio': false,
        'video': {
          'facingMode': 'environment',
          'width': {'ideal': 720},
          'height': {'ideal': 1280},
        },
      };

      print("Attempting to get user media...");
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      print("Media stream obtained successfully.");

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) async {
        if (candidate != null) {
          print('Received ICE candidate: ${candidate.toMap()}');
          await http.post(
            Uri.parse('http://10.0.2.2:8080/candidate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'candidate': candidate.toMap(),
            }),
          );
        }
      };

      await _exchangeSDP();
    } catch (e) {
      print("Error during connection initialization: $e");
    }
  }

  Future<void> _exchangeSDP() async {
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    final response = await http.post(
      Uri.parse('http://10.0.2.2:8080/sdp'), // Adjust this to your server URL
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'sdp': offer.sdp, 'type': offer.type}),
    );

    final answer = jsonDecode(response.body);
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(answer['sdp'], answer['type']),
    );
  }

  void closeConnection() {
    _localStream?.dispose();
    _peerConnection?.close();
    _peerConnection = null;
  }
}

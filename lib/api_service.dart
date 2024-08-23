import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://127.0.0.1:5000'; // Your Flask server URL

  // Method to send a frame (Uint8List) to the server and receive a status code (1-4)
  Future<int> sendFrame(Uint8List frameData) async {
    // final url = Uri.parse('$_baseUrl/process_frame');
    //
    // // Encode the frame as Base64
    // String base64Image = base64Encode(frameData);
    //
    // final response = await http.post(
    //   url,
    //   headers: {'Content-Type': 'application/json'},
    //   body: jsonEncode({'frame': base64Image}),
    // );
    //
    // if (response.statusCode == 200) {
    //   final Map<String, dynamic> data = jsonDecode(response.body);
    //   return data['status'];  // This 'status' is received from the server (1-4)
    // } else {
    //   throw Exception('Failed to get status from API');
    // }
    return 1;
  }
}

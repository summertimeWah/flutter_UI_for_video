import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_for_yolov7/video_show/video_page.dart';

class VideoListPage extends StatefulWidget {
  final String? userID;
  final String? userName;

  const VideoListPage({Key? key, required this.userID, this.userName}) : super(key: key);

  @override
  _UserVideosPageState createState() => _UserVideosPageState();
}

class _UserVideosPageState extends State<VideoListPage> {
  List<Map<String, dynamic>> videos = [];

  @override
  void initState() {
    super.initState();
    _fetchUserVideos();
  }

  Future<void> _fetchUserVideos() async {
    try {
      final SupabaseClient supabase = Supabase.instance.client;

      // 從 Supabase 查詢影片資料
      final files = await supabase.from('video').select();

      if (files == null || files.isEmpty) {
        print("No videos found for user.");
        return;
      }

      //print(files); // 直接打印查詢結果

      // 取得每個影片的下載 URL 和名稱
      List<Map<String, String>> videoList = files.map<Map<String, String>>((
          file) {
        return {
          'name': file['videoName'],
          'url': file['url'], // 使用資料庫中的 URL 欄位
        };
      }).toList();

      // 根據影片名稱排序
      videoList.sort((a, b) => b['name']!.compareTo(a['name']!));

      setState(() {
        videos = videoList;
      });
    } catch (e) {
      print("Failed to fetch user videos: $e");
    }
  }


  // Future<void> _deleteVideo(String videoName) async {
  //   try {
  //     final supabaseClient = Supabase.instance.client;
  //     String filePath = '${widget.userID}/$videoName';
  //
  //     final result = await supabaseClient.storage.from('videos').remove([filePath]);
  //
  //     if (result.isEmpty) {
  //       throw Exception('Failed to delete $videoName');
  //     }
  //
  //     setState(() {
  //       videos.removeWhere((video) => video['name'] == videoName);
  //     });
  //
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('$videoName 已刪除')),
  //     );
  //   } catch (e) {
  //     print('Error occurred while deleting $videoName: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('刪除 $videoName 時發生錯誤')),
  //     );
  //   }
  // }
  //
  //
  // Future<void> downloadVideo(String videoName, String videoURL) async {
  //   try {
  //     Directory? appDocDir = await getExternalStorageDirectory();
  //     File downloadToFile;
  //
  //     if (appDocDir != null) {
  //       downloadToFile = File('${appDocDir.path}/$videoName');
  //     } else {
  //       print("didn't get external dictionary");
  //       Directory appDocDir = await getApplicationDocumentsDirectory();
  //       downloadToFile = File('${appDocDir.path}/$videoName');
  //     }
  //
  //     final fileBytes = await Supabase.instance.client.storage.from('videos').download('${widget.userID}/$videoName');
  //
  //     await downloadToFile.writeAsBytes(fileBytes!);
  //
  //     // Show progress dialog
  //     showDialog(
  //       context: context,
  //       barrierDismissible: false,
  //       builder: (BuildContext context) {
  //         return DownloadProgressDialog(videoName: videoName);
  //       },
  //     );
  //   } catch (e) {
  //     print('Error occurred while downloading $videoName: $e');
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Videos')),
      body: videos.isEmpty
          ? Center(child: Text('No videos found'))
          : ListView.builder(
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return ListTile(
            title: Text(video['name'] ?? 'Unnamed Video'),
            trailing: IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () {
                //_launchURL(video['url']!);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerPage(videoURL: video['url']!),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);  // 將字串轉換成 Uri

    if (await canLaunchUrl(uri)) {  // 檢查是否可以打開此 URL
      await launchUrl(uri);  // 打開該 URL
    } else {
      throw 'Could not launch $url';
    }
  }

}
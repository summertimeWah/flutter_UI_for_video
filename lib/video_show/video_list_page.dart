import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  final SupabaseClient supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchUserVideos();
  }

  Future<void> _fetchUserVideos() async {
    try {

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


  Future<void> _deleteVideo(String videoName) async {
    try {
      final supabaseClient = Supabase.instance.client;

      // Construct file path based on the actual storage structure
      String filePath = videoName;

      print('Deleting file at path: $filePath');  // Debug log

      final deleteResponse = await supabase.from('video').delete().eq('videoName', videoName);

      // if (deleteResponse.error != null) {
      //   print('Failed to delete video record from table: ${deleteResponse.error!.message}');
      //   return;
      // }

      // Try deleting the file
      final result = await supabaseClient.storage.from('video').remove([filePath]);

      // if (result.isEmpty) {
      //   throw Exception('Failed to delete $videoName');
      // }

      setState(() {
        videos.removeWhere((video) => video['name'] == videoName);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$videoName 已刪除')),
      );
      Navigator.pop(context); // This will navigate back to the main page

    } catch (e) {
      print('Error occurred while deleting $videoName: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除 $videoName 時發生錯誤')),
      );
    }
  }

  Future<void> downloadVideo(String videoName) async {
    try {
      Directory? appDocDir = await getExternalStorageDirectory();
      File downloadToFile;

      if (appDocDir != null) {
        downloadToFile = File('${appDocDir.path}/$videoName');
      } else {
        print("Didn't get external directory");
        Directory appDocDir = await getApplicationDocumentsDirectory();
        downloadToFile = File('${appDocDir.path}/$videoName');
      }

      // Construct file path based on the actual storage structure
      final filePath = videoName;
      print('Downloading file from path: $filePath');  // Debug log

      // Try downloading the file
      final fileBytes = await Supabase.instance.client.storage
          .from('video')
          .download(filePath);

      if (fileBytes != null) {
        await downloadToFile.writeAsBytes(fileBytes);

        // Share the video file
        final result = await Share.shareXFiles(
          [XFile(downloadToFile.path)],
          text: 'Check this video out!',
        );

        if (result.status == ShareResultStatus.success) {
          print('Thank you for sharing the video!');
        }
      } else {
        print("Failed to download video");
      }
    } catch (e) {
      print('Error occurred while downloading $videoName: $e');
    }
  }



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
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'play') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerPage(videoURL: video['url']!),
                    ),
                  );
                } else if (value == 'share') {
                  downloadVideo(video['name']);
                }
                else{
                  _deleteVideo(video['name']);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'play',
                  child: ListTile(
                    leading: Icon(Icons.play_arrow),
                    title: Text('播放'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('分享'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete,color: Colors.red),
                    title: Text('刪除'),
                    textColor: Colors.red,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


}
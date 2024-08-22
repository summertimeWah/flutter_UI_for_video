import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_for_yolov7/video_show/video_page.dart';

class VideoListPage extends StatefulWidget {
  final String? userID;
  final String? userName;

  const VideoListPage({Key? key, required this.userID, this.userName}) : super(key: key);

  @override
  _UserVideosPageState createState() => _UserVideosPageState();
}

class _UserVideosPageState extends State<VideoListPage> {
  List<Map<String, String>> videos = [];

  @override
  void initState() {
    super.initState();
    _fetchUserVideos();
  }

  Future<void> _fetchUserVideos() async {
    print("fetching...");
    try {
      // 指定使用者的資料夾路徑
      String folderPath = '/${widget.userID}/';

      // 從 Firebase Storage 中列出該資料夾下的所有檔案
      ListResult result = await FirebaseStorage.instance.ref(folderPath).listAll();

      // 取得每個影片的下載 URL 和名稱
      List<Map<String, String>> videoList = await Future.wait(result.items.map((Reference ref) async {
        String downloadURL = await ref.getDownloadURL();
        return {
          'name': ref.name, // 檔案名稱
          'url': downloadURL, // 檔案下載 URL
        };
      }).toList());

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
      String goalPath = '/${widget.userID}/$videoName';
      await FirebaseStorage.instance.ref(goalPath).delete();
      setState(() {
        videos.removeWhere((video) => video['name'] == videoName);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$videoName 已刪除')),
      );
    } catch (e) {
      print('Error occurred while deleting $videoName: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刪除 $videoName 時發生錯誤')),
      );
    }
  }

  Future<void> downloadVideo(String videoName, String videoURL) async {
    final ref = FirebaseStorage.instance.refFromURL(videoURL);

    try {
      Directory? appDocDir = await getExternalStorageDirectory();
      File downloadToFile;

      if (appDocDir != null) {
        downloadToFile = File('${appDocDir.path}/$videoName');
      } else {
        print("didn't get external dictionary");
        Directory appDocDir = await getApplicationDocumentsDirectory();
        downloadToFile = File('${appDocDir.path}/$videoName');
      }

      // 创建下载任务
      final downloadTask = ref.writeToFile(downloadToFile);

      // 显示进度对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return DownloadProgressDialog(downloadTask: downloadTask, videoName: videoName);
        },
      );
    } catch (e) {
      print('Error occurred while downloading $videoName: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.userName} 的影片"),
      ),
      body: videos.isEmpty
          ? Center(child: Text('尚未有資料'))
          : ListView.builder(
        itemCount: videos.length,
        itemBuilder: (context, index) {
          String videoName = videos[index]['name']!;
          String videoURL = videos[index]['url']!;

          return ListTile(
            title: Text(videoName),
            trailing: PopupMenuButton<String>(
              onSelected: (String value) {
                if (value == '下載') {
                  downloadVideo(videoName, videoURL);
                } else if (value == '刪除') {
                  _deleteVideo(videoName);
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  PopupMenuItem<String>(
                    value: '下載',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('下載'),
                        Icon(Icons.download),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: '刪除',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('刪除', style: TextStyle(color: Colors.red)),
                        Icon(Icons.delete, color: Colors.red),
                      ],
                    ),
                  ),
                ];
              },
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoPlayerPage(videoURL: videoURL),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class DownloadProgressDialog extends StatefulWidget {
  final DownloadTask downloadTask;
  final String videoName;

  const DownloadProgressDialog({Key? key, required this.downloadTask, required this.videoName}) : super(key: key);

  @override
  _DownloadProgressDialogState createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    widget.downloadTask.snapshotEvents.listen((taskSnapshot) {
      setState(() {
        switch (taskSnapshot.state) {
          case TaskState.running:
            _progress = taskSnapshot.bytesTransferred / (taskSnapshot.totalBytes ?? 1);
            break;
          case TaskState.paused:
            print("Download paused for ${widget.videoName}.");
            break;
          case TaskState.success:
            print("Download complete for ${widget.videoName}.");
            Navigator.of(context).pop(); // 关闭对话框
            break;
          case TaskState.canceled:
            print("Download canceled for ${widget.videoName}.");
            Navigator.of(context).pop(); // 关闭对话框
            break;
          case TaskState.error:
            print("Download failed with error for ${widget.videoName}.");
            Navigator.of(context).pop(); // 关闭对话框
            break;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Downloading ${widget.videoName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: _progress),
          SizedBox(height: 20),
          Text('${(_progress * 100).toStringAsFixed(2)}% complete'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Implement cancel logic here if needed
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
      ],
    );
  }
}

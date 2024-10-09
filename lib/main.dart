import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_for_yolov7/signup/sign_up_page.dart';
import 'package:video_for_yolov7/speed_unit.dart';
import 'package:video_for_yolov7/toast_set/toast.dart';
import 'package:video_for_yolov7/video_show/video_list_page.dart';
import 'camera_page.dart';
import 'estimate_speed.dart';
import '/signup/login_page.dart';
import 'firebase_options.dart';

import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:show_fps/show_fps.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://oxskmydkkwzllyxnbcny.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im94c2tteWRra3d6bGx5eG5iY255Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mjc4NDIxMjMsImV4cCI6MjA0MzQxODEyM30.1yxXD6y6Vdfhj2mleREd9dpcI-XmMiP3S8Ng-XhQOvw',

  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    var currentUser = Supabase.instance.client.auth.currentSession?.user;  // 用 Supabase 驗證用戶
    return MaterialApp(
      title: 'Video and Speed App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
      routes: {
        '/login': (context) => LoginPage(),
        '/signUp': (context) => SignUpPage(),
        '/home': (context) => MyApp(),
        '/viedoList': (context) => VideoListPage(
          userID: currentUser?.id,  // 使用 Supabase User ID
          userName: currentUser?.email,  // 使用 Supabase email 作為名稱
        ),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isRecording = false;
  String currentSpeed = "0.0 km/h";
  final GlobalKey<SpeedPageState> _speedPageKey = GlobalKey<SpeedPageState>();
  SpeedUnit speedUnit = SpeedUnit.KPH;

  var currentUser = Supabase.instance.client.auth.currentSession?.user;  // 用 Supabase 來處理用戶信息
  bool isGranted = false;

  @override
  void initState() {
    super.initState();
  }

  void toggleRecording() {
    if (currentUser == null) {
      // 如果未登錄，顯示提示框並返回
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Error"),
          content: Text("You haven't logged in. Please log in first."),
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
      return; // 終止函數，避免繼續執行錄製邏輯
    }

    _checkAndRequestLocationPermission();
    if(!isGranted){
      return;
    }

    // 只有在使用者已經登錄的情況下才會進行錄製操作
    setState(() {
      isRecording = !isRecording;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final speedPageState = _speedPageKey.currentState;

      if (isRecording) {
        if (speedPageState != null) {
          speedPageState.startMeasurement();
        } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text("Error"),
              content: Text("SpeedPage is not ready. Please try again later."),
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
      } else {
        speedPageState?.stopMeasurement();
      }
    });
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
      isGranted = true;

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

  void updateSpeed(double speed) {
    setState(() {
      currentSpeed = speedUnit.format(speed); // 使用 SpeedUnit 格式化速度
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text('Video and Speed App'),
        actions: [
          Builder(
            builder: (context) =>
                IconButton(
                  icon: Icon(Icons.menu),
                  onPressed: () {
                    // 使用 Builder 包裹以确保有一个 Scaffold 上下文
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            currentUser != null
                ? Column(
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(currentUser?.email ?? 'No Name'),  // 用 Supabase email
                  accountEmail: Text(currentUser?.email ?? 'No Email'),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      currentUser?.email != null && currentUser!.email!.length > 4
                          ? currentUser!.email!.substring(0, 4)
                          : currentUser?.email ?? 'User',
                    ),
                  ),
                ),
                ListTile(
                  title: Text("Home"),
                  trailing: Icon(Icons.new_releases),
                  onTap: () {
                    Navigator.pushNamed(context, "/viedoList");  // Close the drawer
                  },
                ),
                Divider(),
                ListTile(
                  title: Text("log out"),
                  trailing: Icon(Icons.logout),
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut(); // 不需要檢查回應物件，signOut 會直接執行
                    setState(() {
                      currentUser = Supabase.instance.client.auth.currentSession?.user;  // 更新 currentUser 為 null
                    });
                    showToast(message: "User is successfully logged out");
                    Navigator.pushNamed(context, "/home");
                  },
                ),
              ],
            )
                : Column(
              children: [
                const UserAccountsDrawerHeader(
                  accountName: Text('Please login'),
                  accountEmail: Text(''),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text("None"),
                  ),
                ),
                ListTile(
                  title: Text("Login"),
                  trailing: Icon(Icons.person),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginPage()));
                  },
                ),
              ],
            ),
            Divider(),
            ListTile(
              title: Text("Close"),
              trailing: Icon(Icons.close),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          CameraPage(
            toggleRecording: toggleRecording,
            isRecording: isRecording,
            currentSpeed: currentSpeed,
          ),
          if (isRecording)
            SpeedPage(
              key: _speedPageKey,
              onSpeedUpdate: updateSpeed,
            ),
        ],
      ),
    );
  }
}

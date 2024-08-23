import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAppCheck.instance.activate(
    //androidProvider: AndroidProvider.playIntegrity,
    androidProvider: AndroidProvider.debug,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    var currentUser = FirebaseAuth.instance.currentUser;
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
        '/viedoList':(context) => VideoListPage( userID: currentUser?.uid, userName: currentUser?.displayName,),
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

  var currentUser = FirebaseAuth.instance.currentUser;

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
                    accountName: Text(currentUser!.displayName ?? 'No Name'),
                    accountEmail: Text(currentUser!.email ?? 'No Email'),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        currentUser!.displayName != null && currentUser!.displayName!.length > 4
                            ? currentUser!.displayName!.substring(0, 4)
                            : currentUser!.displayName ?? 'User',
                      ),
                    ),
                  ),
                  ListTile(
                    title: Text("Home"),
                    trailing: Icon(Icons.new_releases),
                    onTap: () {
                      Navigator.pushNamed(context, "/viedoList"); // Close the drawer
                    },
                  ),
                  Divider(),
                  ListTile(
                    title: Text("log out"),
                    trailing: Icon(Icons.logout),

                    onTap: () {
                      FirebaseAuth.instance.signOut();
                      setState(() {
                        currentUser = FirebaseAuth.instance.currentUser; // 重新取得 currentUser
                      });
                      currentUser = null;
                      showToast(message: "User is successfully logout");
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

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:intl/intl.dart';
import 'home_page.dart';
import 'assistant_page.dart';
import 'timetable_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await localNotifier.setup(
    appName: '梦启时',
    // Only for Windows
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '梦启时',
      theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: "SourceHanSans"
      ),
      home: MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final List<ChatMessage> messages = [];
  final List<Map<String, String>> chatHistory = [];
  final TextEditingController proxyController = TextEditingController(
      text: Platform.isWindows ? '127.0.0.1:10809' : '10.122.237.203:10811');
  final TextEditingController backendIpController =
  TextEditingController(text: '10.122.227.179');

  bool _toughMode = false;  // Added tough mode variable
  bool _enteredOnce = false; // Used to track if it's the second time entering the reminder dialog

  int _selectedIndex = 0;
  late List<Widget> _widgetOptions = <Widget>[
    HomePage(backendIpController: backendIpController),
    AssistantPage(
        messages: messages,
        chatHistory: chatHistory,
        proxyController: proxyController),
    TimetablePage(backendIpController: backendIpController),
  ];

  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkForReminders();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _updateReminderTime(String startTime, String endTime) async {
    final response = await http.post(
      Uri.parse('http://${backendIpController.text}:8000/update_time'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'start_time': startTime, 'end_time': endTime}),
    );

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('提交失败')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成功提交')),
      );
    }
  }


  void _showSettingsDialog() {
    final TextEditingController startTimeController =
    TextEditingController(text: '00:00:00');
    final TextEditingController endTimeController =
    TextEditingController(text: '02:45:00');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('设置'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: proxyController,
                    decoration: InputDecoration(
                      labelText: 'HTTP代理配置(ip:port)',
                    ),
                  ),
                  TextField(
                    controller: backendIpController,
                    decoration: InputDecoration(
                      labelText: '后端IP地址',
                    ),
                  ),
                  TextField(
                    controller: startTimeController,
                    decoration: InputDecoration(
                      labelText: '提醒时间 - 有早八 (HH:mm:ss)',
                    ),
                  ),
                  TextField(
                    controller: endTimeController,
                    decoration: InputDecoration(
                      labelText: '提醒时间 - 无早八 (HH:mm:ss)',
                    ),
                  ),
                  if (Platform.isWindows)
                    Tooltip(
                      message: '第二次触发提醒时将强制退出游戏',
                      child: CheckboxListTile(
                        title: Text("狠人模式"),
                        value: _toughMode,
                        onChanged: (bool? value) {
                          setState(() {
                            _toughMode = value ?? false;
                          });
                        },
                      ),
                    ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('取消'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('确定'),
                  onPressed: () {
                    _updateReminderTime(
                        startTimeController.text, endTimeController.text);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _checkForReminders() async {
    // test only
    // 获取当前时间
    // final now = DateTime.now();
    // final formattedTime = DateFormat('HH:mm').format(now);
    //
    // // 判断时间是否大于02:40
    // if (formattedTime.compareTo('02:55') > 0) {
    //   await _showReminderDialog('Reminder: 该睡觉了！现在是: 02:55。');
    // }
    // return;
    //await _showReminderDialog('111');
    final response = await http
        .get(Uri.parse('http://${backendIpController.text}:5000/remind'));
    // final response = await http.get(Uri.parse('http://10.122.227.179:8000/remind'));
    if (response.statusCode == 200) {
      String reminder = json.decode(response.body)['reminder'];
      if (reminder.isNotEmpty) {
        await _showReminderDialog(reminder);
      }
    }
  }

  Future<void> _showReminderDialog(String reminder) async {
    // Check if it's the second time entering the dialog and tough mode is enabled
    if (_enteredOnce && _toughMode && Platform.isWindows) {
      await Process.run('taskkill', ['/f', '/im', 'Overwatch.exe']);
    }

    await _showNotificationAllPlatform(reminder);
    _enteredOnce = true;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('时间到啦'),
          content: Text(reminder),
          actions: [
            TextButton(
              onPressed: () {
                _postReminderChoice('delay');
                Navigator.of(context).pop();
              },
              child: const Text('等会'),
            ),
            TextButton(
              onPressed: () {
                _postReminderChoice('on-time');
                Navigator.of(context).pop();
              },
              child: const Text('好的'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _postReminderChoice(String choice) async {
    final response = await http.post(
      Uri.parse('http://${backendIpController.text}:5000/log_choice'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'reminder_time': DateTime.now().toIso8601String(),
        'choice': choice,
      }),
    );
    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to log choice')),
      );
    }
  }

  Future<void> _showNotificationAllPlatform(String str) async {
    if(Platform.isAndroid) {
      final android_details = AndroidNotificationDetails(
          'mqs', '梦启时',
          channelDescription: '梦启时提醒',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker');
      final platformspec = NotificationDetails(android: android_details);
      await flutterLocalNotificationsPlugin.show(
          1767, "梦启时提醒", str, platformspec);
    }
    else if(Platform.isWindows){
      final notification = LocalNotification(
        identifier: '12345',
        title: '梦启时提醒',
        body: str,
        silent: false,
      );
      notification.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('梦启时'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '主页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: '助手',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.table_chart),
            label: '课表',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}

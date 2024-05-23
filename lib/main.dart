import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'home_page.dart';
import 'assistant_page.dart';
import 'timetable_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('app_icon');
  final InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '梦启时',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  final TextEditingController proxyController = TextEditingController(text: '127.0.0.1:10809');
  final TextEditingController backendIpController = TextEditingController(text: '10.122.227.179');

  int _selectedIndex = 0;
  late List<Widget> _widgetOptions = <Widget>[
    HomePage(backendIpController: backendIpController),
    AssistantPage(messages: messages, chatHistory: chatHistory, proxyController: proxyController),
    TimetablePage(backendIpController: backendIpController),
  ];

  @override
  void initState(){
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
    final TextEditingController startTimeController = TextEditingController(text: '00:00:00');
    final TextEditingController endTimeController = TextEditingController(text: '01:00:00');

    showDialog(
      context: context,
      builder: (BuildContext context) {
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
                  labelText: '提醒开始时间 (HH:mm:ss)',
                ),
              ),
              TextField(
                controller: endTimeController,
                decoration: InputDecoration(
                  labelText: '提醒结束时间 (HH:mm:ss)',
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
                _updateReminderTime(startTimeController.text, endTimeController.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkForReminders() async {
    final response = await http.get(Uri.parse('http://${backendIpController.text}:8000/remind'));
    // final response = await http.get(Uri.parse('http://10.122.227.179:8000/remind'));
    if (response.statusCode == 200) {
      String reminder = json.decode(response.body)['reminder'];
      if (reminder.isNotEmpty) {
        _showReminderDialog(reminder);
      }
    }
  }

  void _showReminderDialog(String reminder) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reminder'),
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
      Uri.parse('http://${backendIpController.text}:8000/log_choice'),
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

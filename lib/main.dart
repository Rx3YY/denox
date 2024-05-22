import 'package:flutter/material.dart';
import 'home_page.dart';
import 'assistant_page.dart';
import 'timetable_page.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminder App',
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
    TimetablePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showSettingsDialog() {
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
              child: Text('保存'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reminder App'),
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

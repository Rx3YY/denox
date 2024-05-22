import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TimetablePage extends StatefulWidget {
  @override
  _TimetablePageState createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  final List<List<String>> _timetable = List.generate(7, (_) => List.filled(12, ''));

  void _importTimetable(String timetableStr) {
    List<String> days = timetableStr.split('\n');
    for (String day in days) {
      List<String> lessons = day.split(',');
      if (lessons.isEmpty) continue;

      int dayIndex = _matchWeekday(lessons[0]);
      if (dayIndex == -1) continue;

      for (int i = 1; i < lessons.length; i++) {
        final match = RegExp(r'(\d+)-(\d+)节(.*)').firstMatch(lessons[i]);
        if (match != null) {
          int start = int.parse(match.group(1)!);
          int end = int.parse(match.group(2)!);
          String name = match.group(3)!;
          for (int j = start - 1; j < end; j++) {
            _timetable[dayIndex][j] = name;
          }
        }
      }
    }
    setState(() {});
  }

  int _matchWeekday(String day) {
    switch (day) {
      case '周一':
        return 0;
      case '周二':
        return 1;
      case '周三':
        return 2;
      case '周四':
        return 3;
      case '周五':
        return 4;
      case '周六':
        return 5;
      case '周日':
        return 6;
      default:
        return -1;
    }
  }

  void _submitTimetable() async {
    final response = await http.post(
      Uri.parse('http://10.122.227.179:5050/submit'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'data': _serializeTimetable()}),
    );
    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit timetable')),
      );
    }
  }

  String _serializeTimetable() {
    final days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    String result = '';

    for (int i = 0; i < _timetable.length; i++) {
      result += days[i];
      for (int j = 0; j < _timetable[i].length; j++) {
        if (_timetable[i][j].isNotEmpty) {
          result += ',${j + 1}节${_timetable[i][j]}';
        }
      }
      result += '\n';
    }

    return result;
  }

  void _importFromClipboard() async {
    ClipboardData? clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null) {
      _importTimetable(clipboardData.text!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Timetable'),
        actions: [
          IconButton(
            icon: Icon(Icons.content_paste),
            onPressed: _importFromClipboard,
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部星期日期View
          SizedBox(
            child: GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: 8,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 1 / 1,
              ),
              itemBuilder: (BuildContext context, int index) {
                return Container(
                  color: index == 0 ? Colors.white : Colors.lightBlueAccent,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          index == 0 ? '星期' : ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][index - 1],
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        SizedBox(height: 5),
                        Text(
                          index == 0 ? '日期' : '日期数据',  // 这里可以添加日期逻辑
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // 中间课表View
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                children: [
                  // 左侧课程节次指引
                  Expanded(
                    flex: 1,
                    child: GridView.builder(
                      shrinkWrap: true,
                      itemCount: 12,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 1,
                        childAspectRatio: 1 / 2,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          child: Center(
                            child: Text(
                              (index + 1).toString(),
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            border: Border.all(color: Colors.black12, width: 0.5),
                          ),
                        );
                      },
                    ),
                  ),
                  // 中间课程表
                  Expanded(
                    flex: 7,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: 84,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1 / 2,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        int day = index % 7;
                        int time = index ~/ 7;
                        return Container(
                          child: TextField(
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 16.0),
                            ),
                            controller: TextEditingController(text: _timetable[day][time]),
                            onChanged: (value) {
                              setState(() {
                                _timetable[day][time] = value;
                              });
                            },
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.black12, width: 0.5),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _submitTimetable,
        child: Icon(Icons.check),
      ),
    );
  }
}

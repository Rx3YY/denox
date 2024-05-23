import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TimetablePage extends StatefulWidget {
  final TextEditingController backendIpController;

  TimetablePage({required this.backendIpController});

  @override
  State<StatefulWidget> createState() => PageState();
}

class PageState extends State<TimetablePage> {
  final List<List<String>> _timetable =
      List.generate(7, (_) => List.filled(14, ''));
  final List<List<bool>> _isMerged =
      List.generate(7, (_) => List.filled(14, false));

  var colorList = [
    Colors.red,
    Colors.lightBlueAccent,
    Colors.grey,
    Colors.cyan,
    Colors.amber,
    Colors.deepPurpleAccent,
    Colors.purpleAccent
  ];

  var weekList = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  var timeList = [
    '8:00\n8:45',
    '8:50\n9:35',
    '9:50\n10:35',
    '10:40\n11:25',
    '11:30\n12:15',
    '13:00\n13:45',
    '13:50\n14:35',
    '14:50\n15:35',
    '15:40\n16:25',
    '16:30\n17:15',
    '17:20\n18:05',
    '18:30\n19:15',
    '19:20\n20:05',
    '20:10\n20:55'
  ];

  var dateList = [];
  var currentWeekIndex = 0;

  @override
  void initState() {
    super.initState();
    var monday = 1;
    var mondayTime = DateTime.now();
    while (mondayTime.weekday != monday) {
      mondayTime = mondayTime.subtract(Duration(days: 1));
    }
    for (int i = 0; i < 7; i++) {
      dateList.add("${mondayTime.month}/${mondayTime.day + i}");
      if ((mondayTime.day + i) == DateTime.now().day) {
        setState(() {
          currentWeekIndex = i + 1;
        });
      }
    }
    _loadTimetable();
  }

  void _loadTimetable() async {
    final response = await http.get(
      Uri.parse('http://${widget.backendIpController.text}:8000/schedule'),
    );
    if (response.statusCode == 200) {
      _importTimetable(json.decode(response.body)['data']);
    } else {
      _showError('Failed to load timetable');
    }
  }

  void _importTimetable(String timetableStr) {
    for (var i = 0; i < _timetable.length; i++) {
      _timetable[i] = List.filled(14, '');
      _isMerged[i] = List.filled(14, false);
    }
    List<String> days = timetableStr.split('\n');
    for (String day in days) {
      if(day.isEmpty) continue;
      List<String> lessons = day.split(',');
      if (lessons.isEmpty) continue;
      int dayIndex = _matchWeekday(lessons[0]);
      if (dayIndex == -1) {
        _showError('Invalid timetable format');
        return;
      }
      for (int i = 1; i < lessons.length; i++) {
        final match = RegExp(r'(\d+)-(\d+)节(.*)').firstMatch(lessons[i]);
        if (match != null) {
          int start = int.parse(match.group(1)!);
          int end = int.parse(match.group(2)!);
          String name = match.group(3)!;
          if (start > end || start <= 0 || end > 14) {
            _showError('Invalid timetable format');
            return;
          }
          for (int j = start - 1; j < end; j++) {
            _timetable[dayIndex][j] = name;
            _isMerged[dayIndex][j] = true;
          }
          _isMerged[dayIndex][start - 1] = false;
        }
      }
    }
    setState(() {});
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
      Uri.parse('http://${widget.backendIpController.text}:8000/submit'),
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
        if (_timetable[i][j].isNotEmpty && !_isMerged[i][j]) {
          int start = j + 1;
          int end = j + 1;
          while (end < _timetable[i].length &&
              _timetable[i][end] == _timetable[i][j] &&
              _isMerged[i][end]) {
            end++;
          }
          result +=
              ',${start == end ? '$start节' : '$start-$end节'}${_timetable[i][j]}';
          j = end - 1;
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
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _submitTimetable,
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 8,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8, childAspectRatio: 1 / 1),
                itemBuilder: (BuildContext context, int index) {
                  return Container(
                    color: index == currentWeekIndex
                        ? const Color(0x00f7f7f7)
                        : Colors.white,
                    child: Center(
                      child: index == 0
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("星期",
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.black87)),
                                const SizedBox(height: 5),
                                const Text("日期",
                                    style: TextStyle(fontSize: 12)),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(weekList[index - 1],
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: index == currentWeekIndex
                                            ? Colors.lightBlue
                                            : Colors.black87)),
                                const SizedBox(height: 5),
                                Text(dateList[index - 1],
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: index == currentWeekIndex
                                            ? Colors.lightBlue
                                            : Colors.black87)),
                              ],
                            ),
                    ),
                  );
                }),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: GridView.builder(
                      shrinkWrap: true,
                      itemCount: 14,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 1, childAspectRatio: 1 / 2),
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          decoration: const BoxDecoration(
                            color: Color(0xff5ff5),
                            border: Border(
                              bottom:
                                  BorderSide(color: Colors.black12, width: 0.5),
                              right:
                                  BorderSide(color: Colors.black12, width: 0.5),
                            ),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Text(
                                  '${index + 1}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                Text(
                                  timeList[index],
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    flex: 7,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 14 * 7,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1 / 2,
                      ),
                      itemBuilder: (BuildContext context, int index) {
                        int day = index % 7;
                        int time = index ~/ 7;
                        if (_isMerged[day][time]) {
                          return Container();
                        }
                        int span = 1;
                        while (time + span < 14 &&
                            _timetable[day][time + span] ==
                                _timetable[day][time] &&
                            _isMerged[day][time + span]) {
                          span++;
                        }
                        return Container(
                          decoration: BoxDecoration(
                            color: _timetable[day][time].isEmpty
                                ? Colors.white
                                : colorList[day % colorList.length],
                            border:
                                Border.all(color: Colors.black12, width: 0.5),
                          ),
                          child: Center(
                            child: TextField(
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding:
                                    EdgeInsets.symmetric(vertical: 16.0),
                              ),
                              controller: TextEditingController(
                                  text: _timetable[day][time]),
                              onChanged: (value) {
                                setState(() {
                                  _timetable[day][time] = value;
                                });
                              },
                            ),
                          ),
                          height: 50.0 * span,
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
    );
  }
}

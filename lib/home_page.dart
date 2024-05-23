import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class HomePage extends StatefulWidget {
  final TextEditingController backendIpController;
  HomePage({
    required this.backendIpController
  });
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _weatherInfo = '正在加载...';
  String _recommendation = '';

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final response = await http.get(Uri.parse('http://${widget.backendIpController.text}:8000/weather'));
    // final response = await http.get(Uri.parse('http://10.122.227.179:8050/weather'));
    if (response.statusCode == 200) {
      setState(() {
        _weatherInfo = json.decode(response.body)['weather'];
      });
    } else {
      setState(() {
        _weatherInfo = '加载天气失败(${response.statusCode})';
      });
    }
  }

  Future<void> _getRecommendation() async {
    // final response = await http.get(Uri.parse('http://10.122.227.179:5000/recommend'));
    final response = await http.get(Uri.parse('http://${widget.backendIpController.text}:8000/recommend'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _recommendation = data['recommendation'];
      });

      // 提取 recommendedCanteen 值
      final match = RegExp(r'(\d+)号').firstMatch(_recommendation);
      int recommendedCanteen = match != null ? int.parse(match.group(1)!) : -1;

      _showRecommendationDialog(recommendedCanteen);
    } else {
      setState(() {
        _recommendation = '加载推荐失败';
      });
    }
  }

  void _showRecommendationDialog(int recommendedCanteen) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('今日推荐'),
          content: Text(_recommendation),
          actions: [
            TextButton(
              onPressed: () {
                _postChoice(1, recommendedCanteen);
                Navigator.of(context).pop();
              },
              child: const Text('餐厅1'),
            ),
            TextButton(
              onPressed: () {
                _postChoice(2, recommendedCanteen);
                Navigator.of(context).pop();
              },
              child: const Text('餐厅2'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _postChoice(int choice, int recommendedCanteen) async {
    final response = await http.post(
      Uri.parse('http://${widget.backendIpController.text}:8000/record_choice'),
      // Uri.parse('http://10.122.227.179:5000/record_choice'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'choice': choice, 'recommended_canteen': recommendedCanteen}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data.containsKey('alternate_recommendation')) {
        final alternateRecommendation = data['alternate_recommendation'];
        if (alternateRecommendation is String && alternateRecommendation.isNotEmpty) {
          _showAlternateRecommendationDialog(alternateRecommendation);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit choice')),
      );
    }
  }

  void _showAlternateRecommendationDialog(String recommendation) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新的推荐'),
          content: Text(recommendation),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }



  Future<bool> _isOnline() async {
    final response = await http.get(Uri.parse('http://${widget.backendIpController.text}:8000/status'));
    if (response.statusCode == 200) {
      String status = json.decode(response.body)['status'];
      return status == 'ONLINE';
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('主页'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                _weatherInfo,
                style: const TextStyle(
                  fontSize: 24, // 更大字体
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60), // 更大间距
              ElevatedButton(
                onPressed: _getRecommendation,
                style: ElevatedButton.styleFrom(
                  //backgroundColor : Colors.blue, // 按钮颜色
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20), // 加宽按钮
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8), // 矩形按钮
                  ),
                  textStyle: const TextStyle(fontSize: 20), // 更大字体
                ),
                child: const Text('今天吃什么？'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

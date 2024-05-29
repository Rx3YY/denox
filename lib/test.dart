import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:convert';
import 'dart:io';

class AssistantPage extends StatefulWidget {
  final List<ChatMessage> messages;
  final List<Map<String, String>> chatHistory;
  final TextEditingController proxyController;

  AssistantPage({
    required this.messages,
    required this.chatHistory,
    required this.proxyController,
  });

  @override
  _AssistantPageState createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> with AutomaticKeepAliveClientMixin {
  final TextEditingController _controller = TextEditingController();
  IOClient? _client;
  bool _isProxyValid = true;
  String? _proxyErrorMessage;

  @override
  void initState() {
    super.initState();
    _setupProxy();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setupProxy() {
    if (widget.proxyController.text.isNotEmpty) {
      final proxy = widget.proxyController.text;
      try {
        final httpClient = HttpClient();
        httpClient.findProxy = (uri) {
          return "PROXY $proxy";
        };
        httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        _client = IOClient(httpClient);
        setState(() {
          _isProxyValid = true;
          _proxyErrorMessage = null;
        });
        print("Proxy set to: $proxy");
      } catch (e) {
        setState(() {
          _isProxyValid = false;
          _proxyErrorMessage = 'Invalid proxy: $e';
        });
        print("Invalid proxy: $e");
      }
    } else {
      _client = IOClient(HttpClient());
      setState(() {
        _isProxyValid = true;
        _proxyErrorMessage = null;
      });
      print("No proxy set");
    }
  }

  void _sendMessage() {
    if (_controller.text.isEmpty) {
      return;
    }

    setState(() {
      widget.messages.add(ChatMessage(text: _controller.text, isSentByUser: true));
      widget.chatHistory.add({'role': 'user', 'content': _controller.text});
    });

    _fetchResponse(_controller.text);

    _controller.clear();
  }

  Future<void> _fetchResponse(String query) async {
    try {
      // Check if this is the first message
      bool isFirstMessage = widget.chatHistory.length == 1;

      String prompt = query;
      if (isFirstMessage) {
        prompt = "你是一名经验丰富的心理咨询师，拥有多年处理各种心理问题的专业背景。"
            "用户是一名南京师范大学的本科学生，最近遇到了一些心理困扰。"
            "用户描述了以下情况：'$query'"
            "\n\n"
            "请为用户提供一个详细的心理咨询方案，内容包括但不限于："
            "\n\n"
            "1. **理解用户的情绪和感受**："
            " - 向用户解释他们的情绪和感受是正常的，并不是他们的错。"
            " - 帮助用户认识到，接受自己的情绪是管理和缓解困扰的第一步。"
            "\n\n"
            "2. **提供具体的应对策略和技巧**："
            " - 针对用户描述的问题，提供具体的应对策略和技巧。"
            " - 可以包括深呼吸、放松练习、时间管理技巧等。"
            "\n\n"
            "3. **生活方式调整建议**："
            " - 强调保持健康的生活方式对心理健康的重要性。"
            " - 提供具体的建议，例如保持规律的作息时间、健康饮食和适度运动。"
            "\n\n"
            "4. **寻找问题的根源并解决**："
            " - 引导用户回顾并识别引发困扰的具体原因。"
            " - 提供解决问题的策略，例如逐步解决问题的方法或寻求他人的帮助。"
            "\n\n"
            "5. **寻求支持和资源**："
            " - 鼓励用户与家人、朋友或同学分享他们的感受，以获得情感上的支持。"
            " - 建议用户考虑参加支持小组或寻求专业心理咨询师的帮助。"
            "\n\n"
            "6. **建立积极的思维模式**："
            " - 教授用户一些积极思考的方法，帮助他们应对负面情绪和想法。"
            " - 提供练习，如每日记录积极事件或练习感恩日记。"
            "\n\n"
            "7. **持续的自我照顾**："
            " - 提醒用户定期检查自己的心理状态，并及时采取行动管理压力。"
            " - 强调长期坚持健康的生活习惯和应对策略的重要性。"
            "\n\n"
            "最后，提供一些有用的资源，例如推荐的书籍、在线课程或手机应用，以帮助用户进一步学习和提升心理健康。";
      }

      final response = await _client!.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_API_KEY_HERE',
          'Accept-Charset': 'utf-8',
        },
        body: utf8.encode(json.encode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        })),
      ).timeout(const Duration(seconds: 10)); // 增加超时时间

      if (response.statusCode == 200) {
        final responseData = json.decode(utf8.decode(response.bodyBytes));
        final message = responseData['choices'][0]['message']['content'];

        setState(() {
          widget.messages.add(ChatMessage(text: message, isSentByUser: false));
          widget.chatHistory.add({'role': 'assistant', 'content': message});
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to OpenAI')),
        );
        print('Failed to connect to OpenAI: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('助手'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final message = widget.messages[index];
                return ListTile(
                  title: Align(
                    alignment: message.isSentByUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: message.isSentByUser ? Colors.blue : Colors.grey,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        message.text,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '发送消息',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isSentByUser;

  ChatMessage({required this.text, required this.isSentByUser});
}

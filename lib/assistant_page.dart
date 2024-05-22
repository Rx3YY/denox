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
      final response = await _client!.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer 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',
          'Accept-Charset': 'utf-8',
        },
        body: utf8.encode(json.encode({
          'model': 'gpt-3.5-turbo',
          'messages': widget.chatHistory,
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
        title: const Text('Assistant'),
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

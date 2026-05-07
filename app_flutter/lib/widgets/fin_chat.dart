import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_config.dart';

class FinChatWidget extends StatefulWidget {
  const FinChatWidget({super.key});

  @override
  State<FinChatWidget> createState() => _FinChatWidgetState();
}

class _FinChatWidgetState extends State<FinChatWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [
    {"sender": "ai", "text": "Olá! Sou o FinChat. Como posso te ajudar hoje?"},
  ];
  bool _isTyping = false;

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final userMsg = _controller.text;
    setState(() {
      _messages.add({"sender": "user", "text": userMsg});
      _isTyping = true;
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        setState(() {
          _messages.add({
            "sender": "ai",
            "text":
                "Sessão inválida. Faça login novamente para usar o FinChat.",
          });
          _isTyping = false;
        });
        return;
      }

      final token = session.accessToken;
      final response = await http.post(
        Uri.parse('$apiBaseUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({"message": userMsg}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Verifica se o status retornado pelo seu Python é de sucesso
        if (jsonResponse['status'] == 'success' &&
            jsonResponse['data'] != null) {
          final aiText = jsonResponse['data']['response'];
          setState(() {
            _messages.add({"sender": "ai", "text": aiText});
          });
        } else {
          // Se o Python retornou erro (como o 429 da IA)
          final errorMsg =
              jsonResponse['message'] ?? "Erro desconhecido na IA.";
          setState(() {
            _messages.add({
              "sender": "ai",
              "text": "IA indisponível: $errorMsg",
            });
          });
        }
      } else {
        // Erros de servidor (500, 404, etc)
        throw Exception("Erro no servidor: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "sender": "ai",
          "text":
              "Tive um problema ao processar sua mensagem. Verifique se o servidor Python está rodando.",
        });
      });
    } finally {
      setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.slate800,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            "FinChat IA",
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Divider(color: AppColors.slate800),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, i) => _buildBubble(_messages[i]),
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: LinearProgressIndicator(
                color: AppColors.emeraldColor,
                minHeight: 2,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: "Pergunte algo...",
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.slate800,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.emeraldColor),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, String> msg) {
    bool isAi = msg['sender'] == 'ai';
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isAi
              ? AppColors.slate800
              : AppColors.emeraldColor.withAlpha((0.2 * 255).round()),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isAi ? 4 : 16),
            bottomRight: Radius.circular(isAi ? 16 : 4),
          ),
        ),
        child: Text(
          msg['text']!,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        ),
      ),
    );
  }
}

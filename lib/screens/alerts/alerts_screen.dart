import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../constants/app_constants.dart';

class EnquiryScreen extends StatefulWidget {
  const EnquiryScreen({super.key});

  @override
  State<EnquiryScreen> createState() => _EnquiryScreenState();
}

class _EnquiryScreenState extends State<EnquiryScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _inputFocused = false;
  late AnimationController _typingAnimController;

  @override
  void initState() {
    super.initState();
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(text: message, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.chatbotApiBaseUrl}/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add(
            ChatMessage(
              text: data['response'] ?? 'No response',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      } else {
        // Print detailed error for debugging
        print('Chatbot error - Status: ${response.statusCode}');
        print('Response body: ${response.body}');
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  'Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unable to get response'}',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Chatbot exception: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _messages.add(
          ChatMessage(
            text: 'Connection error: $e',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.gradientBackground,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildDivider(),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : _buildMessageList(),
            ),
            if (_isLoading) _buildTypingIndicator(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.neonGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.neonGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.neonGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Enquiry',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.neonGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.neonGreen.withValues(alpha: 0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Online · Ready to help',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Message count badge
          if (_messages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.neonGreen.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                '${_messages.length}',
                style: const TextStyle(
                  color: AppColors.neonGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.neonGreen.withValues(alpha: 0.15),
            AppColors.surfaceDark,
            AppColors.neonGreen.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Decorative orb
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.neonGreen.withValues(alpha: 0.18),
                    AppColors.neonGreen.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: AppColors.neonGreen.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.neonGreen,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'How can I help you?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ask anything about crowd conditions,\nroutes, or real-time updates.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            // Quick prompts
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _QuickPromptChip(
                  label: '🚉 Best time to travel',
                  onTap: () {
                    _messageController.text =
                        'What is the best time to travel?';
                    setState(() {});
                  },
                ),
                _QuickPromptChip(
                  label: '📍 Current crowd levels',
                  onTap: () {
                    _messageController.text = 'Show current crowd levels';
                    setState(() {});
                  },
                ),
                _QuickPromptChip(
                  label: '🗺️ Suggest a route',
                  onTap: () {
                    _messageController.text = 'Suggest the least crowded route';
                    setState(() {});
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final isFirst = index == 0;
        final showDateSeparator =
            isFirst ||
            _messages[index].timestamp.day !=
                _messages[index - 1].timestamp.day;
        return Column(
          children: [
            if (showDateSeparator)
              _buildDateSeparator(_messages[index].timestamp),
            _ChatBubble(message: _messages[index]),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.surfaceDark)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDate(date),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: AppColors.surfaceDark)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day) return 'TODAY';
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.neonGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.neonGreen.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.neonGreen,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AppColors.surfaceDark, width: 1),
            ),
            child: _TypingDots(controller: _typingAnimController),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(
            color: AppColors.neonGreen.withValues(
              alpha: _inputFocused ? 0.2 : 0.08,
            ),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Focus(
              onFocusChange: (focused) =>
                  setState(() => _inputFocused = focused),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceDark.withValues(alpha: 0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: AppColors.neonGreen.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: AppColors.surfaceDark,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: AppColors.neonGreen.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: GestureDetector(
              onTap: _isLoading ? null : _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                      _messageController.text.trim().isNotEmpty && !_isLoading
                      ? AppColors.neonGreen
                      : AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow:
                      _messageController.text.trim().isNotEmpty && !_isLoading
                      ? [
                          BoxShadow(
                            color: AppColors.neonGreen.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  color:
                      _messageController.text.trim().isNotEmpty && !_isLoading
                      ? AppColors.backgroundDark
                      : AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing Dots ──────────────────────────────────────────────────────────────

class _TypingDots extends StatelessWidget {
  final AnimationController controller;
  const _TypingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final double phase = (controller.value - i * 0.15).clamp(0.0, 1.0);
            final double opacity =
                (0.4 + 0.6 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2)).clamp(
                  0.4,
                  1.0,
                );
            final double scale =
                0.7 + 0.3 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// ── Quick Prompt Chip ────────────────────────────────────────────────────────

class _QuickPromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickPromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.neonGreen.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Data Model ───────────────────────────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

// ── Chat Bubble ──────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: AppColors.neonGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.neonGreen.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.neonGreen,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? AppColors.neonGreen
                        : AppColors.cardDark,
                    borderRadius: message.isUser
                        ? const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(4),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          )
                        : const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(18),
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          ),
                    border: message.isUser
                        ? null
                        : Border.all(color: AppColors.surfaceDark, width: 1),
                    boxShadow: message.isUser
                        ? [
                            BoxShadow(
                              color: AppColors.neonGreen.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser
                          ? AppColors.backgroundDark
                          : AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.neonGreen.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

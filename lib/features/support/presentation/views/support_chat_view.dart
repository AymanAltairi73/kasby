import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import '../../data/models/chat_message_model.dart';
import '../controllers/support_chat_controller.dart';

class SupportChatView extends StatefulWidget {
  const SupportChatView({super.key});

  @override
  State<SupportChatView> createState() => _SupportChatViewState();
}

class _SupportChatViewState extends State<SupportChatView> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupportChatController _chatController =
      Get.find<SupportChatController>();

  bool _showSearch = false;
  ChatMessageModel? _editingMessage;
  final Set<String> _expandedMessages = {};

  @override
  void initState() {
    super.initState();
    // No need to load history here, controller handles it
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

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    await _chatController.sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _editMessage(ChatMessageModel message) {
    setState(() {
      _editingMessage = message;
      _messageController.text = message.content;
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    Get.snackbar(
      'copied'.tr,
      'copied_to_clipboard'.tr,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      backgroundColor: AppColors.darkGold.withValues(alpha: 0.2),
    );
  }


  void _deleteMessage(ChatMessageModel message) {
    _chatController.deleteMessage(message.id);
  }



  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_showSearch) _buildSearchBar(),
          Expanded(
            child: Obx(() {
              if (_chatController.isLoading.value &&
                  _chatController.messages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              return Stack(
                children: [
                   // Premium Background
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.background,
                            AppColors.background.withValues(alpha: 0.8),
                            Colors.black,
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildMessagesList(),
                ],
              );
            }),
          ),
          Obx(
            () => _chatController.messages.isNotEmpty
                ? _buildQuickActions()
                : const SizedBox.shrink(),
          ),
          if (_editingMessage != null) _buildEditingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Get.back(),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.darkGold, width: 2),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.darkGold,
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.softGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'kasby_support'.tr,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Obx(
                  () => Row(
                    children: [
                      if (_chatController.isTyping.value)
                        Text(
                          'is_typing'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.darkGold,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        Text(
                          'online_now'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.softGreen,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            setState(() => _showSearch = !_showSearch);
          },
        ),
        PopupMenuButton(
          icon: const Icon(Icons.more_vert_rounded),
          itemBuilder: (context) => [
            PopupMenuItem(
              child: Text('clear_conversation'.tr),
              onTap: () {
                Get.snackbar('soon'.tr, 'feature_soon_desc'.tr);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'search_conversations'.tr,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          prefixIcon: Icon(Icons.search, color: AppColors.darkGold),
          suffixIcon: IconButton(
            icon: Icon(Icons.close, color: Colors.white54),
            onPressed: () {
              _searchController.clear();
              setState(() => _showSearch = false);
            },
          ),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
          onChanged: (value) => _chatController.searchQuery.value = value,
          onSubmitted: (value) => _chatController.searchQuery.value = value,
        ),
    ).animate().fadeIn().slideY(begin: -0.5, end: 0);
  }

  Widget _buildEditingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.darkGold.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.edit, color: AppColors.darkGold, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'edit_message'.tr,
              style: TextStyle(color: AppColors.darkGold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _messageController.clear();
              });
            },
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.5, end: 0);
  }

  Widget _buildWelcomeOverlay() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.darkGold.withValues(alpha: 0.3),
                        AppColors.darkGold.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.darkGold, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.darkGold.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: AppColors.darkGold,
                      size: 60,
                    ),
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  duration: const Duration(seconds: 2),
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1),
                )
                .shimmer(
                  duration: const Duration(seconds: 2),
                  color: AppColors.darkGold.withValues(alpha: 0.3),
                ),
            const SizedBox(height: 40),
            Text(
              'connecting_to_support'.tr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) =>
                    Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.darkGold,
                            shape: BoxShape.circle,
                          ),
                        )
                        .animate(
                          onPlay: (c) => c.repeat(),
                          delay: Duration(milliseconds: index * 200),
                        )
                        .fadeOut(duration: 600.ms)
                        .then()
                        .fadeIn(duration: 600.ms),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return Obx(() {
      final messages = _chatController.filteredMessages;
      if (messages.isEmpty) {
        return _buildWelcomeOverlay();
      }

      // Group messages by date
      final Map<String, List<ChatMessageModel>> groupedMessages = {};
      for (var message in messages) {
        final date = intl.DateFormat('yyyy-MM-dd').format(message.createdAt);
        if (!groupedMessages.containsKey(date)) {
          groupedMessages[date] = [];
        }
        groupedMessages[date]!.add(message);
      }

      final keys = groupedMessages.keys.toList();

      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: keys.length + (_chatController.isTyping.value ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == keys.length && _chatController.isTyping.value) {
            return _buildTypingIndicator();
          }

          final date = keys[index];
          final dateMessages = groupedMessages[date]!;

          return Column(
            children: [
              _buildDateSeparator(date),
              ...dateMessages.map((msg) {
                if (msg.isDeleted) {
                  return _buildDeletedMessage(msg);
                }
                return _buildMessageBubble(msg);
              }),
            ],
          );
        },
      );
    });
  }

  Widget _buildDateSeparator(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final today = intl.DateFormat('yyyy-MM-dd').format(now);
    final yesterday = intl.DateFormat('yyyy-MM-dd').format(
      now.subtract(const Duration(days: 1)),
    );

    String label;
    if (dateStr == today) {
      label = 'today'.tr;
    } else if (dateStr == yesterday) {
      label = 'yesterday'.tr;
    } else {
      label = intl.DateFormat('d MMMM yyyy', Get.locale?.languageCode).format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
        ],
      ),
    );
  }

  Widget _buildDeletedMessage(ChatMessageModel message) {
    return Align(
      alignment: message.isFromUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              size: 16,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 8),
            Text(
              'message_deleted'.tr,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel message) {
    final isExpanded = _expandedMessages.contains(message.id);
    final isLongMessage = message.content.length > 200;
    final displayText = isLongMessage && !isExpanded
        ? '${message.content.substring(0, 200)}...'
        : message.content;

    return GestureDetector(
      onLongPress: () {
        _showMessageOptions(message);
      },
      child:
          Align(
                alignment: message.isFromUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: message.isFromUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        gradient: message.isFromUser && message.messageType == 'text'
                            ? LinearGradient(
                                colors: [
                                  AppColors.darkGold,
                                  AppColors.darkGold.withValues(alpha: 0.8),
                                ],
                              )
                            : null,
                        color: message.isFromUser
                            ? (message.messageType == 'image' ? Colors.transparent : null)
                            : AppColors.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(
                            message.isFromUser ? 20 : 4,
                          ),
                          bottomRight: Radius.circular(
                            message.isFromUser ? 4 : 20,
                          ),
                        ),
                        border: (message.isFromUser && message.messageType == 'image')
                            ? null
                            : (message.isFromUser
                                ? null
                                : Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                  )),
                        boxShadow: message.isFromUser && message.messageType == 'text'
                            ? [
                                BoxShadow(
                                  color: AppColors.darkGold.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.messageType == 'image')
                            GestureDetector(
                              onTap: () => Get.to(
                                () => FullScreenImageViewer(
                                  imageUrl: message.content,
                                  tag: message.id,
                                ),
                              ),
                              child: Hero(
                                tag: message.id,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CachedNetworkImage(
                                    imageUrl: message.content,
                                    placeholder: (context, url) => Container(
                                      width: 200,
                                      height: 200,
                                      color: Colors.white10,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: AppColors.darkGold,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.error),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            )
                          else
                            Linkify(
                              onOpen: (link) async {
                                final uri = Uri.parse(link.url);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                              text: displayText,
                              style: TextStyle(
                                color: message.isFromUser
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 15,
                                height: 1.4,
                              ),
                              linkStyle: TextStyle(
                                color: message.isFromUser
                                    ? Colors.blue.shade900
                                    : Colors.blue.shade300,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.isEdited)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    'edited'.tr,
                                    style: TextStyle(
                                      color: message.isFromUser
                                          ? (message.messageType == 'image' ? Colors.white70 : Colors.black.withValues(alpha: 0.5))
                                          : Colors.white.withValues(alpha: 0.4),
                                      fontSize: 10,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              Text(
                                _formatTime(message.createdAt),
                                style: TextStyle(
                                  color: message.isFromUser
                                      ? (message.messageType == 'image' ? Colors.white70 : Colors.black.withValues(alpha: 0.6))
                                      : Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                              if (message.isFromUser) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.done_all_rounded,
                                  size: 15,
                                  color: message.readAt != null
                                      ? (message.messageType == 'image' ? AppColors.darkGold : Colors.blue.shade900)
                                      : (message.messageType == 'image' ? Colors.white38 : Colors.black.withValues(alpha: 0.3)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.2, end: 0, duration: 300.ms),
    );
  }

  void _showMessageOptions(ChatMessageModel message) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionItem(Icons.copy_rounded, 'copy_text'.tr, () {
              Get.back();
              _copyMessage(message.content);
            }),
            if (message.isFromUser) ...[
              _buildOptionItem(Icons.edit_rounded, 'edit_message'.tr, () {
                Get.back();
                _editMessage(message);
              }),
              _buildOptionItem(Icons.delete_rounded, 'delete'.tr, () {
                Get.back();
                _deleteMessage(message);
              }, color: AppColors.error),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.white),
      title: Text(label, style: TextStyle(color: color ?? Colors.white)),
      onTap: onTap,
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (index) =>
                Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.darkGold.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    )
                    .animate(
                      onPlay: (c) => c.repeat(),
                      delay: Duration(milliseconds: index * 150),
                    )
                    .moveY(begin: 0, end: -6, duration: 400.ms)
                    .then()
                    .moveY(begin: -6, end: 0, duration: 400.ms),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.help_outline_rounded, 'text': 'الأسئلة الشائعة'},
      {'icon': Icons.report_problem_outlined, 'text': 'الإبلاغ عن مشكلة'},
      {
        'icon': Icons.account_balance_wallet_outlined,
        'text': 'مشكلة في المحفظة',
      },
      {'icon': Icons.verified_user_outlined, 'text': 'التحقق من الهوية'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: actions.map((action) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => _sendMessage(action['text'] as String),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.darkGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        action['icon'] as IconData,
                        color: AppColors.darkGold,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        action['text'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.3, end: 0);
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.darkGold.withValues(alpha: 0.8),
                      ),
                      onPressed: () => _showAttachmentMenu(),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _editingMessage != null
                              ? 'edit_message_hint'.tr
                              : 'write_message_hint'.tr,
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.emoji_emotions_outlined,
                              color: AppColors.darkGold.withValues(alpha: 0.6),
                            ),
                            onPressed: () {},
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onChanged: (val) {
                          if (val.isNotEmpty) {
                            _chatController.sendTypingEvent();
                          }
                        },
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _sendMessage(_messageController.text);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.darkGold, Color(0xFFE5C173)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.darkGold.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _editingMessage != null
                          ? Icons.check_rounded
                          : Icons.send_rounded,
                      color: Colors.black,
                      size: 22,
                    ),
                  ),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .shimmer(
                  duration: const Duration(seconds: 2),
                  color: Colors.white.withValues(alpha: 0.3),
                ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  Icons.camera_alt_rounded,
                  'الكاميرا',
                  AppColors.darkGold,
                  () {
                    Get.back();
                    _chatController.pickAndSendImage(ImageSource.camera);
                  },
                ),
                _buildAttachmentOption(
                  Icons.image_rounded,
                  'المعرض',
                  Colors.blue,
                  () {
                    Get.back();
                    _chatController.pickAndSendImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  String _formatTime(DateTime date) {
    return intl.DateFormat('HH:mm', Get.locale?.languageCode).format(date);
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: Hero(
          tag: tag,
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(color: AppColors.darkGold),
              ),
              errorWidget: (context, url, error) => const Icon(
                Icons.error,
                color: Colors.white,
              ),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

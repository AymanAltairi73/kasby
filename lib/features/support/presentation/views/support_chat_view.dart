import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import '../../data/models/chat_message_model.dart';
import '../controllers/support_chat_controller.dart';
import '../widgets/chat_attachment_image.dart';
import 'package:kasby/core/utils/chat_attachment_helper.dart';
import 'package:kasby/core/services/snack_service.dart';

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
  final Map<String, GlobalKey> _messageKeys = {};

  GlobalKey _getKeyForMessage(String id) {
    if (!_messageKeys.containsKey(id)) {
      _messageKeys[id] = GlobalKey();
    }
    return _messageKeys[id]!;
  }

  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'SupportChatView',
      method: 'initState',
      feature: 'Support',
      status: 'INFO',
      params: {
        'isAgentChat': _chatController.isAgentChat,
        'isSocialChat': _chatController.isSocialChat,
        'hasPredefinedConversation':
            _chatController.predefinedConversationId != null,
      },
    );
    _scrollController.addListener(_onScroll);
    
    // Jump-to-message listener
    ever(_chatController.currentSearchIndex, (index) {
      if (index >= 0 && index < _chatController.searchResultIds.length) {
        final id = _chatController.searchResultIds[index];
        final key = _messageKeys[id];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.5,
          );
        }
      }
    });
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      
      // If user is more than 300px away from the bottom, show the scroll-to-bottom badge
      final isFar = (maxScroll - currentScroll) > 300;
      _chatController.showScrollToBottom.value = isFar;
      if (!isFar) {
        _chatController.newIncomingCount.value = 0;
      }

      // Load more messages on scroll to top
      if (currentScroll <= _scrollController.position.minScrollExtent + 50) {
        if (_chatController.hasMore.value && !_chatController.isLoadingMore.value) {
          _chatController.loadMoreMessages();
        }
      }
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
        _chatController.newIncomingCount.value = 0;
      }
    });
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final stopwatch = Stopwatch()..start();
    final isEdit = _editingMessage != null;

    try {
      if (isEdit) {
        await _chatController.updateMessage(_editingMessage!.id, text);
        setState(() => _editingMessage = null);
      } else {
        await _chatController.sendMessage(text);
      }
      SafeGetx.debugTrace(
        className: 'SupportChatView',
        method: '_sendMessage',
        feature: 'Support',
        status: 'SUCCESS',
        durationMs: stopwatch.elapsedMilliseconds,
        params: {'isEdit': isEdit},
      );
    } catch (e, stack) {
      SafeGetx.debugTrace(
        className: 'SupportChatView',
        method: '_sendMessage',
        feature: 'Support',
        status: 'ERROR',
        durationMs: stopwatch.elapsedMilliseconds,
        error: e,
        stackTrace: stack,
      );
    }

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
    AppSnack.success('copied'.tr, 'copied_to_clipboard'.tr);
  }


  void _deleteMessage(ChatMessageModel message) {
    _chatController.deleteMessage(message.id);
  }



  @override
  void dispose() {
    SafeGetx.debugTrace(
      className: 'SupportChatView',
      method: 'dispose',
      feature: 'Support',
      status: 'INFO',
    );
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
        tooltip: 'back'.tr,
        onPressed: () => Get.safeBack(),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              Obx(() {
                final isSupport = _chatController.isKasbySupportChat;
                final avatarUrl = _chatController.recipientAvatarUrl.value;
                final name = _chatController.chatTitle;

                if (isSupport) {
                  return Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.darkGold, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.darkGold,
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  );
                }

                String initials(String value) {
                  final parts = value.trim().split(' ');
                  if (parts.length >= 2) {
                    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
                  }
                  return value.isNotEmpty ? value[0].toUpperCase() : '?';
                }

                final imageProvider = (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null;

                return Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.darkGold, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.darkGold.withValues(alpha: 0.15),
                    backgroundImage: imageProvider,
                    child: imageProvider == null
                        ? Text(
                            initials(name),
                            style: TextStyle(
                              color: AppColors.darkGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                );
              }),
              Obx(() => (_chatController.isKasbySupportChat ||
                      _chatController.isRecipientOnline.value)
                  ? Positioned(
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
                    )
                  : const SizedBox.shrink()),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _chatController.chatTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Obx(
                  () {
                    if (_chatController.isTyping.value) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'is_typing'.tr,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.darkGold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _buildTinyBouncingDots(),
                        ],
                      );
                    }
                    
                    if (_chatController.isKasbySupportChat ||
                        _chatController.isRecipientOnline.value) {
                      return Text(
                        'kasby_support_online_now'.tr,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.softGreen,
                        ),
                      );
                    }

                    final lastSeen = _chatController.recipientLastSeen.value;
                    if (lastSeen != null) {
                      // Formatting last seen
                      final diff = DateTime.now().difference(lastSeen);
                      String timeStr = 'offline'.tr;
                      if (diff.inMinutes < 60) {
                        timeStr = '${diff.inMinutes} دقيقة';
                      } else if (diff.inHours < 24) {
                        timeStr = '${diff.inHours} ساعة';
                      } else {
                        timeStr = '${diff.inDays} يوم';
                      }
                      
                      return Text(
                        'last_seen_ago'.trArgs([timeStr]),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      );
                    }

                    return Text(
                      'offline'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'search'.tr,
          onPressed: () {
            setState(() => _showSearch = !_showSearch);
          },
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'search_conversations'.tr,
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                prefixIcon: Icon(Icons.search, color: AppColors.darkGold),
                suffixIcon: IconButton(
                  icon: Icon(Icons.close, color: Colors.white54),
                  tooltip: 'close'.tr,
                  onPressed: () {
                    _searchController.clear();
                    _chatController.searchMessages('');
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
              onChanged: (value) => _chatController.searchMessages(value),
              onSubmitted: (value) => _chatController.searchMessages(value),
            ),
          ),
          Obx(() {
            if (_chatController.searchResultIds.isEmpty) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                  tooltip: 'back'.tr,
                  onPressed: _chatController.previousSearchResult,
                ),
                Text(
                  '${_chatController.currentSearchIndex.value + 1}/${_chatController.searchResultIds.length}',
                  style: const TextStyle(color: Colors.white70),
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  tooltip: 'next'.tr,
                  onPressed: _chatController.nextSearchResult,
                ),
              ],
            );
          }),
        ],
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
            tooltip: 'close'.tr,
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

      return Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              if (_chatController.hasMore.value) {
                await _chatController.loadMoreMessages();
              }
            },
            color: AppColors.darkGold,
            backgroundColor: AppColors.surface,
            child: ListView.builder(
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
            ),
          ),
          Positioned(
            bottom: 16,
            left: Get.locale?.languageCode == 'ar' ? 16 : null,
            right: Get.locale?.languageCode == 'ar' ? null : 16,
            child: Obx(() {
              if (!_chatController.showScrollToBottom.value) {
                return const SizedBox.shrink();
              }
              return _buildScrollToBottomButton();
            }),
          ),
        ],
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

    return Obx(() {
      final isCurrentSearch = _chatController.searchResultIds.isNotEmpty &&
          _chatController.currentSearchIndex.value >= 0 &&
          _chatController.currentSearchIndex.value < _chatController.searchResultIds.length &&
          _chatController.searchResultIds[_chatController.currentSearchIndex.value] == message.id;

      return Container(
        key: _getKeyForMessage(message.id),
        decoration: isCurrentSearch 
            ? BoxDecoration(
                color: AppColors.darkGold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        padding: isCurrentSearch ? const EdgeInsets.all(4) : EdgeInsets.zero,
        child: GestureDetector(
          onLongPress: () {
            _showMessageOptions(message);
          },
          child: Dismissible(
            key: ValueKey('reply_${message.id}'),
            direction: DismissDirection.startToEnd,
            confirmDismiss: (direction) async {
              _chatController.setReplyingTo(message);
              return false;
            },
            background: Container(
              color: Colors.transparent,
              alignment: Get.locale?.languageCode == 'ar' ? Alignment.centerRight : Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child:  Icon(
                Icons.reply_rounded,
                color: AppColors.darkGold,
              ),
            ),
            child: Align(
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
                          if (message.replyToId != null)
                            _buildReplyParentPreview(message),
                          if (message.messageType == 'image')
                            GestureDetector(
                              onTap: () => Get.to(
                                () => FullScreenImageViewer(
                                  imageContent: message.content,
                                  tag: message.id,
                                ),
                              ),
                              child: Hero(
                                tag: message.id,
                                child: ChatAttachmentImage(
                                  content: message.content,
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
                                _buildDeliveryStatusIcon(message),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                     if (message.reactions.isNotEmpty)
                      Container(
                        margin: EdgeInsets.only(
                          bottom: 12,
                          left: message.isFromUser ? 0 : 8,
                          right: message.isFromUser ? 8 : 0,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _buildGroupedReactions(message.reactions, message),
                        ),
                      ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.2, end: 0, duration: 300.ms),
          ),
        ),
      );
    });
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['👍', '❤️', '😂', '😮', '😢'].map((emoji) {
                final hasReacted = message.reactions.contains(emoji);
                return GestureDetector(
                  onTap: () {
                    Get.safeBack();
                    _chatController.addReaction(message.id, emoji);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasReacted ? AppColors.darkGold.withValues(alpha: 0.2) : Colors.white10,
                      shape: BoxShape.circle,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 8),
            _buildOptionItem(Icons.copy_rounded, 'copy_text'.tr, () {
              Get.safeBack();
              _copyMessage(message.content);
            }),
            if (message.isFromUser) ...[
              _buildOptionItem(Icons.edit_rounded, 'edit_message'.tr, () {
                Get.safeBack();
                _editMessage(message);
              }),
              _buildOptionItem(Icons.delete_rounded, 'delete'.tr, () {
                Get.safeBack();
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
  Widget _buildMessageInput() {
    return Obx(() {
      final replyMsg = _chatController.replyMessage.value;
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyMsg != null) ...[
                _buildInputReplyPreview(replyMsg),
                const SizedBox(height: 8),
              ],
              Row(
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
                            tooltip: 'attach'.tr,
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
                                  tooltip: 'emoji'.tr,
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
                  Semantics(
                    button: true,
                    label: 'Send',
                    child: GestureDetector(
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
                      ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .shimmer(
                        duration: const Duration(seconds: 2),
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  void _closeAttachmentSheetThen(VoidCallback action) {
    if (Get.isBottomSheetOpen ?? false) {
      Get.back();
    }
    Future.microtask(action);
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
                  'camera'.tr,
                  AppColors.darkGold,
                  () {
                    _closeAttachmentSheetThen(
                      () => _chatController.pickAndSendImage(ImageSource.camera),
                    );
                  },
                ),
                _buildAttachmentOption(
                  Icons.image_rounded,
                  'gallery'.tr,
                  Colors.blue,
                  () {
                    _closeAttachmentSheetThen(
                      () => _chatController.pickAndSendImage(ImageSource.gallery),
                    );
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

  List<Widget> _buildGroupedReactions(List<String> reactions, ChatMessageModel message) {
    final Map<String, int> counts = {};
    for (var r in reactions) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    return counts.entries.map((e) {
      final emoji = e.key;
      final count = e.value;
      return GestureDetector(
        onTap: () {
          _chatController.addReaction(message.id, emoji);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            count > 1 ? '$emoji $count' : emoji,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      )
      .animate(key: ValueKey('react_${message.id}_${emoji}_$count'))
      .scale(
        begin: const Offset(0.7, 0.7),
        end: const Offset(1.0, 1.0),
        duration: 300.ms,
        curve: Curves.easeOutBack,
      );
    }).toList();
  }

  Widget _buildDeliveryStatusIcon(ChatMessageModel message) {
    IconData icon;
    Color color;

    final bool isImage = message.messageType == 'image';
    final Color readColor = isImage ? AppColors.darkGold : Colors.blue.shade900;
    final Color unreadColor = isImage ? Colors.white38 : Colors.black.withValues(alpha: 0.3);

    switch (message.status) {
      case MessageStatus.sending:
        icon = Icons.access_time_rounded;
        color = unreadColor;
        break;
      case MessageStatus.sent:
        icon = Icons.check_rounded;
        color = unreadColor;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all_rounded;
        color = unreadColor;
        break;
      case MessageStatus.read:
        icon = Icons.done_all_rounded;
        color = readColor;
        break;
    }

    return Icon(icon, size: 15, color: color);
  }

  String _formatTime(DateTime date) {
    return intl.DateFormat('HH:mm', Get.locale?.languageCode).format(date);
  }

  // ─── Animated Bouncing Dots ───
  Widget _buildTinyBouncingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.darkGold,
            shape: BoxShape.circle,
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(
          begin: 0,
          end: -4,
          duration: 400.ms,
          delay: (i * 150).ms,
          curve: Curves.easeInOut,
        );
      }),
    );
  }

  // ─── Scroll-to-Bottom FAB ───
  Widget _buildScrollToBottomButton() {
    return Semantics(
      button: true,
      label: 'Scroll to bottom',
      child: GestureDetector(
        onTap: _scrollToBottom,
        child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: AppColors.darkGold,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.arrow_downward_rounded, color: Colors.black, size: 22),
            Obx(() {
              final count = _chatController.newIncomingCount.value;
              if (count == 0) return const SizedBox.shrink();
              return Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      ),
    )
    .animate()
    .scale(
      begin: const Offset(0.0, 0.0),
      end: const Offset(1.0, 1.0),
      duration: 200.ms,
      curve: Curves.easeOutBack,
    );
  }

  // ─── Reply Parent Preview (inside message bubble) ───
  Widget _buildReplyParentPreview(ChatMessageModel message) {
    final parentMsg = _chatController.messages
        .firstWhereOrNull((m) => m.id == message.replyToId);
    if (parentMsg == null) return const SizedBox.shrink();

    final isUser = parentMsg.isFromUser;

    return GestureDetector(
      onTap: () {
        // Scroll to the parent message
        final key = _messageKeys[parentMsg.id];
        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.5,
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            right: BorderSide(
              color: isUser ? Colors.white70 : AppColors.darkGold,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isUser ? 'you'.tr : _chatController.chatTitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isUser ? Colors.white70 : AppColors.darkGold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              parentMsg.messageType == 'image'
                  ? '📷 ${'photo'.tr}'
                  : parentMsg.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: message.isFromUser
                    ? Colors.black.withValues(alpha: 0.6)
                    : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Reply Preview (above input bar) ───
  Widget _buildInputReplyPreview(ChatMessageModel replyMsg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.darkGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.reply_rounded, color: AppColors.darkGold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  replyMsg.isFromUser ? 'you'.tr : _chatController.chatTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: replyMsg.isFromUser ? Colors.white70 : AppColors.darkGold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  replyMsg.messageType == 'image'
                      ? '📷 ${'photo'.tr}'
                      : replyMsg.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white60),
            tooltip: 'close'.tr,
            onPressed: () => _chatController.clearReply(),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 200.ms)
    .slideY(begin: 0.3, end: 0, duration: 200.ms);
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageContent;
  final String tag;

  const FullScreenImageViewer({
    super.key,
    required this.imageContent,
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
            child: FutureBuilder<String>(
              future: ChatAttachmentHelper.resolveDisplayUrl(imageContent),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.darkGold),
                  );
                }
                return CachedNetworkImage(
                  imageUrl: snapshot.data!,
                  memCacheWidth: 1200,
                  maxHeightDiskCache: 1200,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(color: AppColors.darkGold),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                  ),
                  fit: BoxFit.contain,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

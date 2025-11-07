import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../config/api_config.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/channel_message.dart';
import '../services/channel_message_service.dart';
import '../utils/storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';
import '../screens/channel_profile_screen.dart';
import 'dart:async';

class ChannelChatScreen extends StatefulWidget {
  final String channelName;
  final String channelDescription;
  final String channelAvatar;
  final int? channelId;
  final bool isPrivate;
  final int membersCount;
  final File? imageFile;
  final String? caption;

  const ChannelChatScreen({
    Key? key,
    required this.channelName,
    required this.channelDescription,
    this.channelAvatar = '',
    this.channelId,
    this.isPrivate = false,
    this.membersCount = 0,
    this.imageFile,
    this.caption,
  }) : super(key: key);

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _showEmojiPicker = false;
  bool _showGifPicker = false;
  List<Map<String, dynamic>> _gifResults = [];
  final String _giphyApiKey = 'GlVGYHkr3WSBnllca54iNt0yFbjz7L65';
  final FocusNode _focusNode = FocusNode();
  String? _gifError;

  // Reply state
  Map<String, dynamic>? _replyTo;

  // Reactions state: message index -> reaction
  Map<int, String> _reactions = {};

  File? _pickedFile;
  String? _pickerError;

  final ScrollController _scrollController = ScrollController();
  Map<String, List<ChannelMessage>> _groupedMessages = {};
  bool _isLoading = false;
  bool _hasMore = true;
  int _limit = 20;
  int _offset = 0;
  String? _error;
  int? _currentUserId;
  List<Map<String, dynamic>> _messages = [];
  Timer? _pollingTimer;
  int? _editingMessageId;
  String? _editingOriginalText;
  List<Map<String, dynamic>> _forwardUsers = [];
  List<Map<String, dynamic>> _forwardChannels = [];
  Set<String> _selectedForwards = {};
  bool _isForwardLoading = false;
  bool _hasAutoScrolled = false;

  @override
  void initState() {
    super.initState();
    _initUserIdAndMessages();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmojiPicker = false;
          _showGifPicker = false;
        });
      }
    });
    if (widget.imageFile != null) {
      setState(() {
        _pickedFile = widget.imageFile;
      });
    }
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
    // Optimized polling for realtime messages - will be replaced with WebSocket when ready
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (mounted) {
        _fetchMessages(forceRefresh: true);
      }
    });
    _hasAutoScrolled = false;
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initUserIdAndMessages() async {
    final id = await Storage.getUserId();
    setState(() {
      _currentUserId = id;
    });
    _fetchMessages();
  }

  Future<void> _fetchMessages({
    bool loadMore = false,
    bool forceRefresh = false,
  }) async {
    if (_isLoading || (!_hasMore && loadMore)) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      String? prevLastMsgId;
      if (forceRefresh && _groupedMessages.isNotEmpty) {
        final dateKeys = _groupedMessages.keys.toList()..sort((a, b) => _parseDate(b).compareTo(_parseDate(a)));
        final lastDate = dateKeys.isNotEmpty ? dateKeys.first : null;
        if (lastDate != null && _groupedMessages[lastDate]!.isNotEmpty) {
          prevLastMsgId = _groupedMessages[lastDate]!.first.id.toString();
        }
      }
      final newMessages = await ChannelMessageService.getChannelMessages(
        channelId: widget.channelId ?? 0,
        limit: _limit,
        offset: forceRefresh ? 0 : _offset,
      );
      
      if (newMessages.isEmpty ||
          newMessages.values.every((list) => list.isEmpty)) {
        setState(() {
          _hasMore = false;
        });
      } else {
        setState(() {
          bool shouldScroll = false;
          if (forceRefresh) {
            final Map<String, List<ChannelMessage>> updatedGrouped = Map.from(_groupedMessages);
            newMessages.forEach((date, newMsgs) {
              final oldMsgs = updatedGrouped[date] ?? [];
              final List<ChannelMessage> mergedList = [
                ...newMsgs.where((newMsg) => !oldMsgs.any((oldMsg) => oldMsg.id == newMsg.id)),
                ...oldMsgs
              ];
              // Remove temp message (id: -1) if a real message with same content and senderId exists
              final List<ChannelMessage> dedupedList = [];
              for (final msg in mergedList) {
                if (msg.id == -1) {
                  // Check if real message with same content and senderId exists
                  final hasReal = mergedList.any((m) => m.id != -1 && m.senderId == msg.senderId && m.content == msg.content);
                  if (hasReal) continue;
                }
                dedupedList.add(msg);
              }
              updatedGrouped[date] = dedupedList;
            });
            _groupedMessages = updatedGrouped;
            
            // Get new last message id
            String? newLastMsgId;
            final dateKeys = newMessages.keys.toList()..sort((a, b) => _parseDate(b).compareTo(_parseDate(a)));
            final lastDate = dateKeys.isNotEmpty ? dateKeys.first : null;
            if (lastDate != null && newMessages[lastDate]!.isNotEmpty) {
              newLastMsgId = newMessages[lastDate]!.first.id.toString();
            }
            shouldScroll = (prevLastMsgId != null && newLastMsgId != null && prevLastMsgId != newLastMsgId);
            
            // Only scroll if a new message is received at the bottom
            if (shouldScroll && _scrollController.hasClients && _scrollController.position.pixels <= 100) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollController.jumpTo(0);
              });
            }
          } else {
          newMessages.forEach((date, msgs) {
            if (_groupedMessages.containsKey(date)) {
                _groupedMessages[date] = [..._groupedMessages[date]!, ...msgs];
            } else {
              _groupedMessages[date] = msgs;
            }
          });
          _offset += _limit;
          }
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100 && _hasMore && !_isLoading) {
      _fetchMessages(loadMore: true);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void showThemedSnackbar(
    BuildContext context,
    String message, {
    bool success = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        success
            ? (isDark
                ? const Color.fromARGB(255, 56, 142, 123)
                : const Color.fromARGB(255, 102, 187, 168))
            : (isDark
                ? const Color.fromARGB(255, 180, 15, 15)
                : const Color.fromARGB(255, 206, 61, 59));
    final icon = success ? Icons.check_circle : Icons.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.18),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          ChannelProfileScreen(channelId: widget.channelId!),
                ),
              );
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE0F2F1),
                  backgroundImage:
                      widget.channelAvatar.isNotEmpty
                          ? NetworkImage(widget.channelAvatar)
                          : null,
                  child:
                      widget.channelAvatar.isEmpty
                          ? Text(
                            widget.channelName.isNotEmpty
                                ? widget.channelName[0]
                                : '',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                      : null,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    widget.channelName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            ChannelProfileScreen(channelId: widget.channelId!),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(color: Colors.white),
          Padding(
            padding: const EdgeInsets.only(bottom: 80, top: 80),
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off, // or Icons.error_outline
                          size: 64,
                          color: AppTheme.primaryColor.withOpacity(0.7),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Oops! Unable to load channel messages.',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'There might be an internet or server issue.\nPlease try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          icon: Icon(Icons.refresh, color: Colors.white),
                          label: Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          onPressed: () {
                            _fetchMessages(forceRefresh: true);
                          },
                        ),
                      ],
                    ),
                  )
                : _buildMessagesList(),
          ),
          if (_pickerError != null)
            Positioned(
              top: 210,
              left: 20,
              child: Text(_pickerError!, style: TextStyle(color: Colors.red)),
            ),
          if (_pickedFile != null)
            Positioned(
              top: 100,
              left: 20,
              child:
                  _pickedFile != null
                      ? Image.file(_pickedFile!, width: 100, height: 100)
                      : SizedBox.shrink(),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(color: AppTheme.primaryColor, width: 4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _replyTo!['senderName'] ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if ((_replyTo!['has_media'] ?? 0) == 1)
                                  Row(
                                    children: [
                                      Icon(Icons.image, size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text('Media', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                    ],
                                  ),
                                if ((_replyTo!['text'] ?? '').isNotEmpty)
                                  Text(
                                    _replyTo!['text'],
                                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                            onPressed: () => setState(() => _replyTo = null),
                          ),
                        ],
                      ),
                    ),
                  if (_showEmojiPicker)
                    SizedBox(
                      height: 250,
                      child: EmojiPicker(
                        onEmojiSelected: (category, emoji) {
                          setState(() {
                            _messageController.text = _messageController.text + emoji.emoji;
                          });
                        },
                      ),
                    ),
                  if (_showGifPicker)
                    Container(
                      height: 250,
                      color: Colors.white,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search GIFs...',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                              ),
                              onChanged: _searchGifs,
                            ),
                          ),
                          if (_gifError != null)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(_gifError!, style: TextStyle(color: Colors.red)),
                            ),
                          Expanded(
                            child: _gifResults.isEmpty
                                ? Center(
                                    child: Text(
                                      'Search for GIFs...',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.all(8),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 1,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                    itemCount: _gifResults.length,
                                    itemBuilder: (context, index) {
                                      final gif = _gifResults[index];
                                      return InkWell(
                                        onTap: () {
                                          final gifUrl = gif['images']['fixed_height']['url'];
                                          showDialog(
                                            context: context,
                                            builder: (context) => Dialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              child: Padding(
                                                padding: const EdgeInsets.all(20),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Text(
                                                      'Send this GIF?',
                                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: Image.network(
                                                        gifUrl,
                                                        width: 220,
                                                        height: 220,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                      children: [
                                                        Expanded(
                                                          child: TextButton(
                                                            onPressed: () => Navigator.pop(context),
                                                            style: TextButton.styleFrom(
                                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(30),
                                                              ),
                                                            ),
                                                            child: const Text('Cancel'),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 16),
                                                        Expanded(
                                                          child: ElevatedButton(
                                                            onPressed: () async {
                                                              final gifUrl = gif['images']['fixed_height']['url'];
                                                              await _sendMessage(gifUrl: gifUrl);
                                                              setState(() {
                                                                _showGifPicker = false;
                                                              });
                                                              Navigator.pop(context);
                                                            },
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: AppTheme.secondaryColor,
                                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(30),
                                                              ),
                                                              elevation: 0,
                                                            ),
                                                            child: const Text(
                                                              'Send',
                                                              style: TextStyle(color: Colors.white),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            gif['images']['fixed_height']['url'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.broken_image, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                    color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey[200]!, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.04),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                                                            ),
                                                          ],
                                                        ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: IntrinsicHeight(
                  child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                              icon: Icon(Icons.emoji_emotions_outlined, color: AppTheme.primaryColor),
                              onPressed: () {
                                            setState(() {
                                  _showEmojiPicker = !_showEmojiPicker;
                                  _showGifPicker = false;
                                });
                                if (_showEmojiPicker) _focusNode.unfocus();
                              },
                              splashRadius: 20,
                              ),
                              IconButton(
                              icon: Icon(_showGifPicker ? Icons.close : Icons.gif_box_outlined, color: AppTheme.primaryColor),
                                onPressed: () {
                                  setState(() {
                                    _showGifPicker = !_showGifPicker;
                                    _showEmojiPicker = false;
                                  if (_showGifPicker) _focusNode.unfocus();
                                  });
                                },
                              splashRadius: 20,
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  focusNode: _focusNode,
                                  decoration: InputDecoration(
                                    hintText: 'Type a message',
                                    border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                  isDense: false,
                                    ),
                                minLines: 1,
                                maxLines: 5,
                                textInputAction: TextInputAction.newline,
                                keyboardType: TextInputType.multiline,
                                ),
                              ),
                              IconButton(
                              icon: Icon(Icons.attach_file, color: AppTheme.primaryColor),
                                onPressed: () async {
                                final result = await showModalBottomSheet<String>(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                  isScrollControlled: true,
                                    builder: (context) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(24),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 16,
                                              offset: Offset(0, -2),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                          horizontal: 8,
                                        ),
                                        child: SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 4,
                                                margin: const EdgeInsets.only(
                                                  bottom: 16,
                                                  top: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[300],
                                                borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                              Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                children: [
                                                  _FilePickerOption(
                                                    icon: Icons.photo,
                                                    label: 'Gallery',
                                                  color: AppTheme.primaryColor,
                                                  onTap: () => Navigator.pop(context, 'gallery'),
                                                  ),
                                                  _FilePickerOption(
                                                    icon: Icons.camera_alt,
                                                    label: 'Camera',
                                                  color: AppTheme.primaryColor,
                                                  onTap: () => Navigator.pop(context, 'camera'),
                                                  ),
                                                  _FilePickerOption(
                                                  icon: Icons.insert_drive_file,
                                                    label: 'Document',
                                                  color: AppTheme.primaryColor,
                                                  onTap: () => Navigator.pop(context, 'document'),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                  if (result != null) {
                                    _pickFile(result);
                                  }
                                },
                              splashRadius: 20,
                              ),
                            ],
                        ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.secondaryColor,
                        child: IconButton(
                          icon: Icon(
                        _editingMessageId != null ? Icons.check : Icons.send,
                            color: Colors.white,
                          ),
                          onPressed: () async {
                            if (_editingMessageId != null) {
                          await _editChannelMessage(_editingMessageId!, _messageController.text.trim());
                              setState(() {
                                _editingMessageId = null;
                                _editingOriginalText = null;
                                _messageController.clear();
                              });
                            } else if (_messageController.text.isNotEmpty) {
                          await _sendMessage();
                              setState(() {
                                _pickedFile = null;
                              });
                          _messageController.clear();
                            }
                          },
                        ),
                      ),
                    ],
                      ),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_currentUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isLoading && _offset == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isLoading && _groupedMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 60,
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 18),
            Text(
              "No messages yet.\nStart the conversation!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.primaryColor.withOpacity(0.7),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    List<String> dateKeys = _groupedMessages.keys.toList();
    dateKeys.sort((a, b) => _parseDate(b).compareTo(_parseDate(a)));
    final allMessages = <Widget>[];
    for (final date in dateKeys) {
      final messages = _groupedMessages[date]!;
      messages.sort((a, b) => _parseTime(a.time).compareTo(_parseTime(b.time)));
      final messageWidgets = <Widget>[];
      for (int i = 0; i < messages.length; i++) {
        final msg = messages[i];
        double bottomMargin = 0;
        if (msg.reactions.isNotEmpty) {
          bottomMargin = 16;
        }
        messageWidgets.add(
          Container(
            margin: EdgeInsets.only(bottom: bottomMargin),
            child: _buildMessageBubble(msg),
          ),
        );
      }
      allMessages.add(
        Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_buildDateHeader(date), ...messageWidgets.reversed],
        ),
      );
    }

    if (_isLoading && _offset > 0) {
      allMessages.add(
        const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (_hasMore && _offset > 0) {
      allMessages.add(_buildLoadMoreButton());
    }

    return ListView(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      children: allMessages,
    );
  }

  Widget _buildMessageBubble(ChannelMessage msg) {
    final bool isMe = _currentUserId != null && msg.senderId == _currentUserId;
    final bool isHtml = RegExp(r'<(div|span|p|br|img|table|style|font|b|strong|a|ul|li|ol|h[1-6]|blockquote|pre|code|iframe|form|input|button|select|option|textarea|hr|em|i|u|s|strike|center|marquee|sup|sub|small|big|abbr|acronym|address|applet|area|article|aside|audio|base|basefont|bdi|bdo|bgsound|blink|body|canvas|caption|cite|col|colgroup|data|datalist|dd|del|details|dfn|dialog|dir|dl|dt|embed|fieldset|figcaption|figure|footer|frame|frameset|head|header|hgroup|html|ins|kbd|label|legend|link|main|map|mark|menu|menuitem|meta|meter|nav|noframes|noscript|object|optgroup|output|param|picture|portal|progress|q|rb|rp|rt|rtc|ruby|samp|script|section|shadow|slot|source|span|strike|style|summary|template|tbody|td|tfoot|th|thead|time|title|tr|track|tt|var|video|wbr)[\s>]').hasMatch(msg.content);
    final bool isBase64Img =
        msg.content.contains('<img') &&
        msg.content.contains('src="data:image/');
    final bool isHtmlImg = msg.content.contains('<img') && msg.content.contains('src="');
    final bool isGif = msg.content.trim().endsWith('.gif') ||
        msg.content.contains('giphy.com/media/') ||
        msg.content.contains('tenor.com/view/') ||
        msg.content.contains('media.giphy.com/media/') ||
        msg.content.contains('media.tenor.com/');

    final imageFiles =
        msg.hasMedia && msg.mediaFiles.isNotEmpty
            ? msg.mediaFiles
                .where(
                  (file) => file.fileType == 'image' || file.fileType == null,
                )
                .toList()
        : <dynamic>[];
    final docFiles =
        msg.hasMedia && msg.mediaFiles.isNotEmpty
            ? msg.mediaFiles
                .where((file) => file.fileType == 'document')
                .toList()
        : <dynamic>[];
    final bool hasMedia = imageFiles.isNotEmpty || docFiles.isNotEmpty;

    Widget contentWidget = const SizedBox.shrink();
    if (msg.hasMedia && msg.mediaFiles.isNotEmpty) {
      if (imageFiles.isNotEmpty) {
        Widget mediaWidget;
        if (imageFiles.length == 1) {
          final file = imageFiles[0];
          mediaWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
            alignment: Alignment.center,
            child: Material(
              color: Colors.transparent,
              elevation: 2,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  showDialog(
                    context: context,
                        builder: (_) => Dialog(
                      backgroundColor: Colors.black,
                      insetPadding: const EdgeInsets.all(0),
                      child: _ImagePreviewSlider(
                        mediaList: [
                          {
                            'url': getFullImageUrl(file.filePath),
                            'sender': msg.userName,
                              }
                        ],
                        initialIndex: 0,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.grey[100],
                    width: 180,
                    height: 180,
                    child: Image.network(
                      getFullImageUrl(file.filePath),
                      fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(Icons.broken_image, color: Colors.grey[400], size: 48),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
              ),
              if (msg.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  msg.content,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ],
          );
        } else if (imageFiles.length == 2) {
          mediaWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (i) {
              final file = imageFiles[i];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                  child: Material(
                    color: Colors.transparent,
                    elevation: 2,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        showDialog(
                          context: context,
                              builder: (_) => Dialog(
                            backgroundColor: Colors.black,
                            insetPadding: const EdgeInsets.all(0),
                            child: _ImagePreviewSlider(
                                  mediaList: imageFiles
                                      .map((file) => {
                                            'url': getFullImageUrl(file.filePath),
                                        'sender': msg.userName,
                                          })
                                  .toList(),
                              initialIndex: i,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: Colors.grey[100],
                          height: 180,
                          child: Image.network(
                            getFullImageUrl(file.filePath),
                            fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(Icons.broken_image, color: Colors.grey[400], size: 48),
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
              ),
              if (msg.content.isNotEmpty) ...[
              const SizedBox(height: 8),
                Text(
                  msg.content,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ],
          );
        } else {
          // 3 or more images
          int showCount = imageFiles.length > 4 ? 4 : imageFiles.length;
          int moreCount = imageFiles.length - 4;
          mediaWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: showCount,
            itemBuilder: (context, index) {
              final file = imageFiles[index];
              Widget img = Material(
                color: Colors.transparent,
                elevation: 2,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    showDialog(
                      context: context,
                          builder: (_) => Dialog(
                        backgroundColor: Colors.black,
                        insetPadding: const EdgeInsets.all(0),
                        child: _ImagePreviewSlider(
                              mediaList: imageFiles
                                  .map((file) => {
                                    'url': getFullImageUrl(file.filePath),
                                    'sender': msg.userName,
                                      })
                              .toList(),
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: Colors.grey[100],
                      child: Image.network(
                        getFullImageUrl(file.filePath),
                        fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.broken_image, color: Colors.grey[400], size: 48),
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );

                  if (index == 3 && moreCount > 0) {
                img = Stack(
                  fit: StackFit.expand,
                  children: [
                    img,
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+$moreCount more',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return img;
            },
              ),
              if (msg.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  msg.content,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ],
            ],
          );
        }
        contentWidget = mediaWidget;
      }

      // Add document files if any
      if (docFiles.isNotEmpty) {
        contentWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            if (contentWidget != const SizedBox.shrink()) ...[
              contentWidget,
              const SizedBox(height: 8),
            ],
            ...docFiles.map((file) {
                    return GestureDetector(
                      onTap: () async {
                        final url = getFullImageUrl(file.filePath);
                        final uri = Uri.parse(url);
                        try {
                          if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                          content: Text('No app found to open this file.'),
                                  ),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                                const Icon(
                                  Icons.insert_drive_file,
                                  color: Colors.blueAccent,
                                ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                file.mediaName ?? 'Document',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            if (msg.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                msg.content,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                ),
              ],
            ],
        );
      }
    } else if (isGif) {
      String gifUrl = msg.content;
      if (msg.content.contains('<img')) {
        final imgReg = RegExp(r'src="([^"]+)"');
        final match = imgReg.firstMatch(msg.content);
        if (match != null) {
          gifUrl = match.group(1)!;
        }
      }
        contentWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            gifUrl.trim(),
            width: 180,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Icon(Icons.broken_image, color: Colors.grey[400], size: 48),
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                      : null,
                ),
              );
            },
          ),
          if (msg.content.isNotEmpty && !msg.content.contains('<img')) ...[
            const SizedBox(height: 8),
            Text(
              msg.content,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ],
      );
    } else if (isBase64Img) {
      final base64Reg = RegExp(r'src="data:image/[^;]+;base64,([^"]+)"');
      final match = base64Reg.firstMatch(msg.content);
      if (match != null) {
        final base64Str = match.group(1)!;
        final bytes = base64Decode(base64Str);
        contentWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.memory(bytes, width: 180, height: 180, fit: BoxFit.cover),
            if (msg.content.isNotEmpty && !msg.content.contains('<img')) ...[
              const SizedBox(height: 8),
              Text(
                msg.content,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ],
        );
      } else {
        contentWidget = const Text('Image not supported');
      }
    } else if (isHtmlImg) {
      final imgReg = RegExp(r'src=\"([^\"]+)\"');
      final match = imgReg.firstMatch(msg.content);
      if (match != null) {
        final imgUrl = match.group(1)!;
        contentWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              imgUrl.trim(),
          width: 180,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(Icons.broken_image, color: Colors.grey[400], size: 48),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                    : null,
              ),
            );
          },
            ),
            if (msg.content.isNotEmpty && !msg.content.contains('<img')) ...[
              const SizedBox(height: 8),
              Text(
                msg.content,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ],
        );
      } else {
        contentWidget = const Text('Image not supported');
      }
    } else if (isHtml) {
      contentWidget = Html(
        data: sanitizeHtml(msg.content),
        style: {
          "h1": Style(fontSize: FontSize(22), fontWeight: FontWeight.bold),
          "h2": Style(fontSize: FontSize(20), fontWeight: FontWeight.bold),
          "h3": Style(fontSize: FontSize(18), fontWeight: FontWeight.bold),
          "p": Style(fontSize: FontSize(16)),
          "div": Style(fontSize: FontSize(16)),
        },
      );
    } else if (msg.content.isNotEmpty) {
      contentWidget = Text(
        msg.content,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      );
    }

    Widget? replyWidget;
    if (msg.replyTo != null && msg.replyTo!.content.isNotEmpty) {
      replyWidget = Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: AppTheme.primaryColor, width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.replyTo!.userName.isNotEmpty
                  ? msg.replyTo!.userName
                  : 'Reply',
        style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              msg.replyTo!.content,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // Prepare reactions widget (if any)
    Widget? reactionsWidget;
    if ((msg.reactions?.isNotEmpty ?? false)) {
      reactionsWidget = Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFE0F2F1) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.06),
              blurRadius: 1.5,
              offset: const Offset(0, 1),
                        ),
                      ],
                    ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: (msg.reactions ?? []).map<Widget>((reaction) {
            final emoji = reaction.emoji;
            final count = reaction.count;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                  Text(emoji, style: const TextStyle(fontSize: 15)),
                  if (count > 1) ...[
                    const SizedBox(width: 2),
                    Text(count.toString(), style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  ],
                ],
                              ),
            );
          }).toList(),
        ),
      );
    }

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMe) const SizedBox(width: 2),
        Flexible(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onLongPress: () async {
                  await showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    builder: (context) {
                      return SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.reply),
                              title: const Text('Reply'),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  _replyTo = {
                                    'isMe': isMe,
                                    'senderName': msg.userName,
                                    'text': msg.content,
                                    'id': msg.id,
                                    'has_media': msg.hasMedia ? 1 : 0,
                                    'media_files': msg.mediaFiles,
                                  };
                                });
                              },
                            ),
                            if (isMe) ListTile(
                              leading: const Icon(Icons.edit),
                              title: const Text('Edit'),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  _editingMessageId = msg.id;
                                  _editingOriginalText = msg.content;
                                  _messageController.text = msg.content;
                                  FocusScope.of(context).requestFocus(_focusNode);
                                });
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.delete_outline),
                              title: const Text('Delete'),
                              onTap: () async {
                                Navigator.pop(context);
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Message'),
                                    content: const Text('Are you sure you want to delete this message?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _deleteMessage(msg.id);
                                }
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.forward),
                              title: const Text('Forward'),
                              onTap: () async {
                                Navigator.pop(context);
                                await _showForwardModal(msg.id);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                onDoubleTap: () {
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                    ),
                    builder: (context) {
                      return SafeArea(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Add Reaction',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _ReactionIcon(
                                    emoji: '👍',
                                    onTap: () async {
                                      // print('DEBUG: Reaction 👍 tapped for message id: \\${msg.id}');
                                      Navigator.pop(context);
                                      try {
                                        final newReactions = await ChannelMessageService.reactToChannelMessage(
                                          messageId: msg.id,
                                          emoji: '👍',
                                        );
                                        // print('DEBUG: Reaction 👍 API call success');
                                        setState(() {
                                          _groupedMessages.forEach((date, msgs) {
                                            for (var i = 0; i < msgs.length; i++) {
                                              if (msgs[i].id == msg.id) {
                                                msgs[i] = ChannelMessage(
                                                  id: msgs[i].id,
                                                  senderId: msgs[i].senderId,
                                                  content: msgs[i].content,
                                                  createdAt: msgs[i].createdAt,
                                                  userName: msgs[i].userName,
                                                  userAvatar: msgs[i].userAvatar,
                                                  isEdited: msgs[i].isEdited,
                                                  isDeleted: msgs[i].isDeleted,
                                                  isForwarded: msgs[i].isForwarded,
                                                  isPinned: msgs[i].isPinned,
                                                  hasMedia: msgs[i].hasMedia,
                                                  mediaFiles: msgs[i].mediaFiles,
                                                  hasVoice: msgs[i].hasVoice,
                                                  replyTo: msgs[i].replyTo,
                                                  reactions: newReactions,
                                                  time: msgs[i].time,
                                                );
                                              }
                                            }
                                          });
                                        });
                                      } catch (e) {
                                        // print('DEBUG: Reaction 👍 API call failed: \\${e.toString()}');
                                        showThemedSnackbar(context, 'Reaction failed: \\${e.toString()}', success: false);
                                      }
                                    },
                                  ),
                                  _ReactionIcon(
                                    emoji: '❤️',
                                    onTap: () async {
                                      // print('DEBUG: Reaction ❤️ tapped for message id: \\${msg.id}');
                                      Navigator.pop(context);
                                      try {
                                        final newReactions = await ChannelMessageService.reactToChannelMessage(
                                          messageId: msg.id,
                                          emoji: '❤️',
                                        );
                                        // print('DEBUG: Reaction ❤️ API call success');
                                        setState(() {
                                          _groupedMessages.forEach((date, msgs) {
                                            for (var i = 0; i < msgs.length; i++) {
                                              if (msgs[i].id == msg.id) {
                                                msgs[i] = ChannelMessage(
                                                  id: msgs[i].id,
                                                  senderId: msgs[i].senderId,
                                                  content: msgs[i].content,
                                                  createdAt: msgs[i].createdAt,
                                                  userName: msgs[i].userName,
                                                  userAvatar: msgs[i].userAvatar,
                                                  isEdited: msgs[i].isEdited,
                                                  isDeleted: msgs[i].isDeleted,
                                                  isForwarded: msgs[i].isForwarded,
                                                  isPinned: msgs[i].isPinned,
                                                  hasMedia: msgs[i].hasMedia,
                                                  mediaFiles: msgs[i].mediaFiles,
                                                  hasVoice: msgs[i].hasVoice,
                                                  replyTo: msgs[i].replyTo,
                                                  reactions: newReactions,
                                                  time: msgs[i].time,
                                                );
                                              }
                                            }
                                          });
                                        });
                                      } catch (e) {
                                        // print('DEBUG: Reaction ❤️ API call failed: \\${e.toString()}');
                                        showThemedSnackbar(context, 'Reaction failed: \\${e.toString()}', success: false);
                                      }
                                    },
                                  ),
                                  _ReactionIcon(
                                    emoji: '😂',
                                    onTap: () async {
                                      // print('DEBUG: Reaction 😂 tapped for message id: \\${msg.id}');
                                      Navigator.pop(context);
                                      try {
                                        final newReactions = await ChannelMessageService.reactToChannelMessage(
                                          messageId: msg.id,
                                          emoji: '😂',
                                        );
                                        // print('DEBUG: Reaction 😂 API call success');
                                        setState(() {
                                          _groupedMessages.forEach((date, msgs) {
                                            for (var i = 0; i < msgs.length; i++) {
                                              if (msgs[i].id == msg.id) {
                                                msgs[i] = ChannelMessage(
                                                  id: msgs[i].id,
                                                  senderId: msgs[i].senderId,
                                                  content: msgs[i].content,
                                                  createdAt: msgs[i].createdAt,
                                                  userName: msgs[i].userName,
                                                  userAvatar: msgs[i].userAvatar,
                                                  isEdited: msgs[i].isEdited,
                                                  isDeleted: msgs[i].isDeleted,
                                                  isForwarded: msgs[i].isForwarded,
                                                  isPinned: msgs[i].isPinned,
                                                  hasMedia: msgs[i].hasMedia,
                                                  mediaFiles: msgs[i].mediaFiles,
                                                  hasVoice: msgs[i].hasVoice,
                                                  replyTo: msgs[i].replyTo,
                                                  reactions: newReactions,
                                                  time: msgs[i].time,
                                                );
                                              }
                                            }
                                          });
                                        });
                                      } catch (e) {
                                        // print('DEBUG: Reaction 😂 API call failed: \\${e.toString()}');
                                        showThemedSnackbar(context, 'Reaction failed: \\${e.toString()}', success: false);
                                      }
                                    },
                                  ),
                                  _ReactionIcon(
                                    emoji: '😮',
                                    onTap: () async {
                                      // print('DEBUG: Reaction 😮 tapped for message id: \\${msg.id}');
                                      Navigator.pop(context);
                                      try {
                                        final newReactions = await ChannelMessageService.reactToChannelMessage(
                                          messageId: msg.id,
                                          emoji: '😮',
                                        );
                                        // print('DEBUG: Reaction 😮 API call success');
                                        setState(() {
                                          _groupedMessages.forEach((date, msgs) {
                                            for (var i = 0; i < msgs.length; i++) {
                                              if (msgs[i].id == msg.id) {
                                                msgs[i] = ChannelMessage(
                                                  id: msgs[i].id,
                                                  senderId: msgs[i].senderId,
                                                  content: msgs[i].content,
                                                  createdAt: msgs[i].createdAt,
                                                  userName: msgs[i].userName,
                                                  userAvatar: msgs[i].userAvatar,
                                                  isEdited: msgs[i].isEdited,
                                                  isDeleted: msgs[i].isDeleted,
                                                  isForwarded: msgs[i].isForwarded,
                                                  isPinned: msgs[i].isPinned,
                                                  hasMedia: msgs[i].hasMedia,
                                                  mediaFiles: msgs[i].mediaFiles,
                                                  hasVoice: msgs[i].hasVoice,
                                                  replyTo: msgs[i].replyTo,
                                                  reactions: newReactions,
                                                  time: msgs[i].time,
                                                );
                                              }
                                            }
                                          });
                                        });
                                      } catch (e) {
                                        // print('DEBUG: Reaction 😮 API call failed: \\${e.toString()}');
                                        showThemedSnackbar(context, 'Reaction failed: \\${e.toString()}', success: false);
                                      }
                                    },
                                  ),
                                  _ReactionIcon(
                                    emoji: '😢',
                                    onTap: () async {
                                      // print('DEBUG: Reaction 😢 tapped for message id: \\${msg.id}');
                                      Navigator.pop(context);
                                      try {
                                        final newReactions = await ChannelMessageService.reactToChannelMessage(
                                          messageId: msg.id,
                                          emoji: '😢',
                                        );
                                        // print('DEBUG: Reaction 😢 API call success');
                                        setState(() {
                                          _groupedMessages.forEach((date, msgs) {
                                            for (var i = 0; i < msgs.length; i++) {
                                              if (msgs[i].id == msg.id) {
                                                msgs[i] = ChannelMessage(
                                                  id: msgs[i].id,
                                                  senderId: msgs[i].senderId,
                                                  content: msgs[i].content,
                                                  createdAt: msgs[i].createdAt,
                                                  userName: msgs[i].userName,
                                                  userAvatar: msgs[i].userAvatar,
                                                  isEdited: msgs[i].isEdited,
                                                  isDeleted: msgs[i].isDeleted,
                                                  isForwarded: msgs[i].isForwarded,
                                                  isPinned: msgs[i].isPinned,
                                                  hasMedia: msgs[i].hasMedia,
                                                  mediaFiles: msgs[i].mediaFiles,
                                                  hasVoice: msgs[i].hasVoice,
                                                  replyTo: msgs[i].replyTo,
                                                  reactions: newReactions,
                                                  time: msgs[i].time,
                                                );
                                              }
                                            }
                                          });
                                        });
                                      } catch (e) {
                                        // print('DEBUG: Reaction 😢 API call failed: \\${e.toString()}');
                                        showThemedSnackbar(context, 'Reaction failed: \\${e.toString()}', success: false);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(
                    left: isMe ? 40 : 8,
                    right: isMe ? 8 : 40,
                    top: 0,
                    bottom: 2,
                  ),
                  padding:
                      imageFiles.length == 1
                      ? const EdgeInsets.symmetric(vertical: 8, horizontal: 0)
                      : imageFiles.length > 1
                          ? const EdgeInsets.only(
                            top: 0,
                            left: 8,
                            right: 8,
                            bottom: 8,
                          )
                          : const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                  constraints:
                      (msg.content.trim().isNotEmpty || imageFiles.isNotEmpty)
                          ? BoxConstraints(
                                maxWidth: imageFiles.length == 1
                        ? 200
                        : MediaQuery.of(context).size.width * 0.78,
                          )
                          : const BoxConstraints(),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFFE0F2F1) : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 6),
                    bottomRight: Radius.circular(isMe ? 6 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                      // Show userName above every message (for all users)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2.0),
                        child: Text(
                          isMe ? 'You' : msg.userName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isMe ? AppTheme.primaryColor : Colors.teal[800],
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (msg.isForwarded) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment:
                                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            Icon(Icons.repeat, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                      Text(
                              'Forwarded',
                        style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                      ),
                      const SizedBox(height: 4),
                    ],
                      if (replyWidget != null) replyWidget,
                    contentWidget,
                    const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                    Text(
                      msg.time,
                            style: TextStyle(color: Colors.black38, fontSize: 12),
                          ),
                          if (msg.isEdited) ...[
                            const SizedBox(width: 4),
                            Text(
                              'Edited',
                      style: TextStyle(
                        color: Colors.black38,
                        fontSize: 12,
                                fontStyle: FontStyle.italic,
                      ),
                    ),
                          ],
                        ],
                      ),
                  ],
                  ),
                ),
              ), // End GestureDetector
              // Reaction bubble
              if ((msg.reactions?.isNotEmpty ?? false))
                Positioned(
                  bottom: -10,
                  right: isMe ? 5 : null,
                  left: isMe ? null : 5,
                  child: SizedBox(
                    height: 28,
                    child: reactionsWidget,
                  ),
                ),
            ],
          ),
        ),
        if (isMe) const SizedBox(width: 2),
      ],
    );
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            date,
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Center(
      child: TextButton(
        onPressed: _isLoading ? null : () => _fetchMessages(loadMore: true),
        child: const Text('Load More'),
      ),
    );
  }

  String decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  String sanitizeHtml(String html) {
    final document = html_parser.parse(html);
    document
        .querySelectorAll('style, script')
        .forEach((element) => element.remove());
    document.body!.querySelectorAll('*').forEach((element) {
      if (element.localName == 'a') {
        element.attributes.removeWhere((key, value) => key != 'href');
      } else {
        element.attributes.clear();
      }
    });
    return document.body!.innerHtml;
  }

  DateTime _parseTime(String time) {
    final now = DateTime.now();
    try {
      final format = DateFormat.jm();
      final parsed = format.parse(time);
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    } catch (e) {
      return now;
    }
  }

  DateTime _parseDate(String key) {
    if (key == 'Today') return DateTime.now();
    if (key == 'Yesterday') return DateTime.now().subtract(Duration(days: 1));
    try {
      return DateFormat('MMMM d, yyyy').parse(key);
    } catch (e) {
      return DateTime(1970);
    }
  }

  Future<void> _searchGifs(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _gifError = null;
      _gifResults = [];
    });
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.giphy.com/v1/gifs/search?api_key=$_giphyApiKey&q=$query&limit=20',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data'].length > 0) {
          setState(() {
            _gifResults = List<Map<String, dynamic>>.from(data['data']);
            _gifError = null;
          });
        } else {
          setState(() {
            _gifError = 'No GIFs found.';
          });
        }
      } else {
        setState(() {
          _gifError = 'Failed to load GIFs. (${response.statusCode})';
        });
      }
    } catch (e) {
      print('Error fetching GIFs: $e');
      setState(() {
        _gifError = 'Error fetching GIFs.';
      });
    }
  }

  Future<void> _pickFile(String type) async {
    // print('DEBUG: Starting file picker for type: $type');
    setState(() {
      _pickerError = null;
    });
    try {
      final picker = ImagePicker();
      XFile? picked;
      if (type == 'camera') {
        // print('DEBUG: Opening camera');
        picked = await picker.pickImage(source: ImageSource.camera);
      } else if (type == 'gallery') {
        // print('DEBUG: Opening gallery');
        picked = await picker.pickImage(source: ImageSource.gallery);
      } else if (type == 'document') {
        // print('DEBUG: Opening document picker');
        picked = await picker.pickImage(source: ImageSource.gallery);
      }
      
      if (picked != null) {
        // print('DEBUG: File picked: ${picked.path}');
        final file = File(picked.path);
        final captionController = TextEditingController();
        final shouldSend = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Send this image?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      file,
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // print('DEBUG: Error loading image preview: $error');
                        return Container(
                          width: 220,
                          height: 220,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: captionController,
                    decoration: InputDecoration(
                      hintText: 'Add a caption...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            side: BorderSide(color: AppTheme.primaryColor),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Send',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        
        if (shouldSend == true) {
          // print('DEBUG: User confirmed sending media');
          setState(() {
            _pickedFile = file;
          });
          await _sendMediaMessage(file, captionController.text);
        } else {
          // print('DEBUG: User cancelled sending media');
        }
      } else {
        // print('DEBUG: No file picked');
      }
    } catch (e) {
      // print('DEBUG: Error in file picker: $e');
      setState(() {
        _pickerError = e.toString();
      });
    }
  }

  Future<void> _sendMediaMessage(File file, String caption) async {
    try {
      // First upload the file
      final token = await Storage.getToken();
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          ApiConfig.uploadChannelMediaEndpoint,
        ),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      request.fields['channel_id'] = widget.channelId.toString();

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Now send the message with the uploaded file
          final messageBody = {
            'channel_id': widget.channelId,
            'message': caption,
            'has_media': 1,
            'has_voice': 0,
            'media_ids': [
              {
                'file_path': data['file_path']
              }
            ]
          };
          
          final messageResponse = await http.post(
            Uri.parse(
              ApiConfig.sendChannelMessageEndpoint,
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(messageBody),
          );

          if (messageResponse.statusCode == 200) {
            final messageData = json.decode(messageResponse.body);
            if (messageData['status'] == 'success') {
              await _fetchMessages(forceRefresh: true);
              setState(() {
                _pickedFile = null;
              });
            } else {
              showThemedSnackbar(
                context,
                    'Message send nahi hua: ${messageData['message'] ?? 'Unknown error'}',
                success: false,
              );
            }
          } else {
            showThemedSnackbar(
              context,
              'Server error: ${messageResponse.statusCode}',
              success: false,
            );
          }
        } else {
          showThemedSnackbar(
            context,
                'File upload nahi hua: ${data['message'] ?? 'Unknown error'}',
            success: false,
          );
        }
      } else {
        showThemedSnackbar(
          context,
          'File upload error: ${response.statusCode}',
          success: false,
        );
      }
    } catch (e) {
      if (e is SocketException) {
        showThemedSnackbar(
        context,
          'Network error: Please check your internet connection',
          success: false,
        );
      } else {
        showThemedSnackbar(
          context,
          'Error: ${e.toString()}',
          success: false,
        );
      }
    }
  }

  String getFullImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    String cleanPath = path
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'^/+'), '');
    return ApiConfig.getAssetUrl(cleanPath);
  }

  Future<void> _sendMessage({String? gifUrl}) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && gifUrl == null) return;

    final message = gifUrl != null ? '<img src="$gifUrl" />' : text;
    _messageController.clear();

    // Check if replying
    final replyTo = _replyTo;
    _replyTo = null;

    // print('DEBUG: Sending message: $message');
    // print('DEBUG: Reply to: $replyTo');

    final now = DateTime.now();
    final tempMsg = ChannelMessage(
      id: -1,
      senderId: _currentUserId ?? 0,
      userName: 'You',
      userAvatar: '',
      content: message,
      time: DateFormat.jm().format(now),
      createdAt: DateFormat('yyyy-MM-dd').format(now),
      hasMedia: false,
      hasVoice: false,
      isEdited: false,
      isDeleted: false,
      isForwarded: false,
      isPinned: false,
      mediaFiles: [],
      reactions: [],
      replyTo:
          replyTo != null
              ? ReplyTo(
                userName: replyTo['senderName'] ?? '',
                content: replyTo['text'] ?? '',
                hasMedia: replyTo['has_media'] == 1,
                mediaFiles:
                    (replyTo['media_files'] as List?)?.cast<MediaFile>() ?? [],
              )
              : null,
    );

    // Optimistic update: add temp message to UI
    setState(() {
      final todayKey = 'Today';
      if (_groupedMessages.containsKey(todayKey)) {
        _groupedMessages[todayKey] = [tempMsg, ..._groupedMessages[todayKey]!];
      } else {
        _groupedMessages[todayKey] = [tempMsg];
      }
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    try {
      final token = await Storage.getToken();
      http.Response response;
      if (replyTo != null && replyTo['id'] != null) {
        // Send reply
        final requestBody = {
          'message_id': replyTo['id'],
          'message': message,
          'has_media': 0,
          'has_voice': 0,
        };
        // print('DEBUG: Sending reply with body: $requestBody');
        response = await http.post(
          Uri.parse(
            ApiConfig.replyChannelMessageEndpoint,
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(requestBody),
        );
      } else {
        // Normal message
        final requestBody = {
          'channel_id': widget.channelId,
          'message': message,
          'has_media': 0,
          'has_voice': 0,
        };
        // print('DEBUG: Sending normal message with body: $requestBody');
        response = await http.post(
          Uri.parse(
            ApiConfig.sendChannelMessageEndpoint,
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(requestBody),
        );
      }
      // print('DEBUG: Message send response status: ${response.statusCode}');
      // print('DEBUG: Message send response body: ${response.body}');
      
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        // print('DEBUG: Message sent successfully, refreshing messages');
        await _fetchMessages(forceRefresh: true);
      } else {
        // print('DEBUG: Failed to send message: ${data['message']}');
        showThemedSnackbar(
          context,
          data['message'] ?? 'Failed to send message',
          success: false,
        );
      }
    } catch (e) {
      // print('DEBUG: Error sending message: $e');
      showThemedSnackbar(context, 'Error: $e', success: false);
    }
  }

  Future<void> _editChannelMessage(int messageId, String newContent) async {
    // print('DEBUG: Editing message $messageId with new content: $newContent');
    final token = await Storage.getToken();
    try {
      final response = await http.put(
        Uri.parse(
          ApiConfig.editChannelMessageEndpoint,
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'message_id': messageId, 'message': newContent}),
      );
      // print('DEBUG: Edit message response status: ${response.statusCode}');
      // print('DEBUG: Edit message response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // print('DEBUG: Message edited successfully');
          // Update message in _groupedMessages
          setState(() {
            _groupedMessages.forEach((date, msgs) {
              for (var i = 0; i < msgs.length; i++) {
                if (msgs[i].id == messageId) {
                  msgs[i] = ChannelMessage(
                    id: msgs[i].id,
                    senderId: msgs[i].senderId,
                    content: data['data']['message'],
                    createdAt: msgs[i].createdAt,
                    userName: msgs[i].userName,
                    userAvatar: msgs[i].userAvatar,
                    isEdited: true,
                    isDeleted: msgs[i].isDeleted,
                    isForwarded: msgs[i].isForwarded,
                    isPinned: msgs[i].isPinned,
                    hasMedia: msgs[i].hasMedia,
                    mediaFiles: msgs[i].mediaFiles,
                    hasVoice: msgs[i].hasVoice,
                    replyTo: msgs[i].replyTo,
                    reactions: msgs[i].reactions,
                    time: msgs[i].time,
                  );
                  break;
                }
              }
            });
          });
        } else {
          // print('DEBUG: Failed to edit message: ${data['message']}');
          showThemedSnackbar(
            context,
            data['message'] ?? 'Edit failed',
            success: false,
          );
        }
      } else {
        // print('DEBUG: Server error while editing message: ${response.statusCode}');
        showThemedSnackbar(
          context,
          'Server error: ${response.statusCode}',
          success: false,
        );
      }
    } catch (e) {
      // print('DEBUG: Error editing message: $e');
      showThemedSnackbar(context, 'Error: $e', success: false);
    }
  }

  Future<void> _showForwardModal(int messageId) async {
    setState(() {
      _isForwardLoading = true;
      _forwardUsers = [];
      _forwardChannels = [];
      _selectedForwards = {};
    });
    final token = await Storage.getToken();
    try {
      final response = await http.get(
        Uri.parse(
          ApiConfig.getForwardListEndpoint,
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _forwardUsers = List<Map<String, dynamic>>.from(
              data['data']['users'] ?? [],
            );
            _forwardChannels = List<Map<String, dynamic>>.from(
              data['data']['channels'] ?? [],
            );
          });
        }
      }
    } catch (e) {
      // ignore
    }
    setState(() {
      _isForwardLoading = false;
    });

    // Find the message to forward for preview
    ChannelMessage? forwardMsg;
    _groupedMessages.forEach((date, msgs) {
      for (final m in msgs) {
        if (m.id == messageId) forwardMsg = m;
      }
    });

    bool isForwarding = false;
    String searchText = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredUsers =
                _forwardUsers.where((user) {
                  final name =
                      ('${user['first_name']} ${user['last_name'] ?? ''}')
                          .toLowerCase();
                  return name.contains(searchText.toLowerCase());
                }).toList();
            final filteredChannels =
                _forwardChannels.where((ch) {
                  final name = (ch['name'] ?? '').toLowerCase();
                  return name.contains(searchText.toLowerCase());
                }).toList();
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 560,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.forward, color: Colors.teal, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Forward Message',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF1e5955),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    if (forwardMsg != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Text(
                          forwardMsg!.content,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search users or channels...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 12,
                        ),
                      ),
                      onChanged: (val) => setModalState(() => searchText = val),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Select users or channels to forward',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child:
                          _isForwardLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ListView(
                                children: [
                                  if (filteredUsers.isNotEmpty) ...[
                                    const Text(
                                      'Users',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                    ...filteredUsers.map(
                                      (user) => CheckboxListTile(
                                        value: _selectedForwards.contains(
                                          '${user['id']}_user',
                                        ),
                                        onChanged: (val) {
                                          setModalState(() {
                                            if (val == true) {
                                              _selectedForwards.add(
                                                '${user['id']}_user',
                                              );
                                            } else {
                                              _selectedForwards.remove(
                                                '${user['id']}_user',
                                              );
                                            }
                                          });
                                        },
                                        title: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: Colors.teal[100],
                                              child: Text(
                                                (user['first_name'] ?? 'U')[0],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                '${user['first_name']} ${user['last_name'] ?? ''}',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (filteredChannels.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Channels',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                    ...filteredChannels.map(
                                      (ch) => CheckboxListTile(
                                        value: _selectedForwards.contains(
                                          '${ch['id']}_channel',
                                        ),
                                        onChanged: (val) {
                                          setModalState(() {
                                            if (val == true) {
                                              _selectedForwards.add(
                                                '${ch['id']}_channel',
                                              );
                                            } else {
                                              _selectedForwards.remove(
                                                '${ch['id']}_channel',
                                              );
                                            }
                                          });
                                        },
                                        title: Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor:
                                                  Colors.orange[100],
                                              child: Text(
                                                (ch['name'] ?? 'C')[0],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(ch['name'] ?? ''),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 120,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed:
                                _selectedForwards.isEmpty || isForwarding
                                    ? null
                                    : () async {
                                      setModalState(() => isForwarding = true);
                                      final forwardTo =
                                          _selectedForwards.map((s) {
                                            final parts = s.split('_');
                                            return {
                                              'type': parts[1],
                                              'id': int.parse(parts[0]),
                                            };
                                          }).toList();

                                      final token = await Storage.getToken();
                                      final body = {
                                        'message_id': messageId,
                                        'forward_to': forwardTo,
                                      };
                                      // print('FORWARD DEBUG: body: $body');
                                      final response = await http.post(
                                        Uri.parse(
                                          ApiConfig.universalForwardEndpoint,
                                        ),
                                        headers: {
                                          'Authorization': 'Bearer $token',
                                          'Content-Type': 'application/json',
                                        },
                                        body: json.encode(body),
                                      );
                                      print(
                                        'FORWARD DEBUG: status: ${response.statusCode}',
                                      );
                                      print(
                                        'FORWARD DEBUG: response: ${response.body}',
                                      );
                                      setModalState(() => isForwarding = false);
                                      if (response.statusCode == 200) {
                                        final data = json.decode(response.body);
                                        if (data['status'] == 'success') {
                                          Navigator.pop(context);
                                        } else {
                                          showThemedSnackbar(
                                            context,
                                            data['message'] ??
                                                'Failed to forward',
                                            success: false,
                                          );
                                        }
                                      } else {
                                        showThemedSnackbar(
                                          context,
                                          'Server error: ${response.statusCode}',
                                          success: false,
                                        );
                                      }
                                    },
                            child:
                                isForwarding
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Text('Forward'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMessage(int messageId) async {
    try {
      await ChannelMessageService.deleteChannelMessageForMe(messageId: messageId);
      setState(() {
        _groupedMessages.forEach((date, msgs) {
          msgs.removeWhere((m) => m.id == messageId);
        });
      });
      if (!mounted) return;
      showThemedSnackbar(context, 'Message deleted successfully', success: true);
    } catch (e) {
      if (!mounted) return;
      showThemedSnackbar(context, 'Failed to delete message: $e', success: false);
    }
  }
}

class _FilePickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _FilePickerOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewSlider extends StatefulWidget {
  final List<Map<String, String>> mediaList;
  final int initialIndex;
  const _ImagePreviewSlider({
    Key? key,
    required this.mediaList,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<_ImagePreviewSlider> createState() => _ImagePreviewSliderState();
}

class _ImagePreviewSliderState extends State<_ImagePreviewSlider> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.mediaList.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, index) {
            return Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      widget.mediaList[index]['url']!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[900],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                                : null,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 30,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.mediaList[index]['sender'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                if (widget.mediaList.length > 1)
                  Positioned(
                    bottom: 30,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${widget.mediaList.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 30,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReactionIcon extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionIcon({required this.emoji, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
} 

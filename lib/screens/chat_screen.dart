import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../config/api_config.dart';
import '../screens/user_profile_screen.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/chat_message.dart';
import '../services/message_service.dart';

import '../utils/storage.dart';
import 'package:http_parser/http_parser.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'pdf_viewer_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatScreen extends StatefulWidget {
  final String userName;
  final String userAvatar;
  final int? chatId;
  final File? imageFile;
  final String? caption;
  final int userId;
  const ChatScreen({super.key, required this.userName, this.userAvatar = '', this.chatId, this.imageFile, this.caption, required this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _showEmojiPicker = false;
  bool _showGifPicker = false;
  List<Map<String, dynamic>> _gifResults = [];
  final String _giphyApiKey = 'GlVGYHkr3WSBnllca54iNt0yFbjz7L65'; // Free Giphy API key
  final FocusNode _focusNode = FocusNode();
  String? _gifError;

  // Reply state
  Map<String, dynamic>? _replyTo;

  // Reactions state: message index -> reaction
  Map<int, String> _reactions = {};

  File? _pickedFile;
  String? _pickerError;

  final ScrollController _scrollController = ScrollController();
  Map<String, List<ChatMessage>> _groupedMessages = {};
  bool _isLoading = false;
  bool _hasMore = true;
  int _limit = 20;
  int _offset = 0;
  String? _error;
  int? _currentUserId;
  Timer? _pollingTimer;

  // Add edit state
  int? _editingMessageId;
  String? _editingOriginalText;

  // Add at the top:
  List<Map<String, dynamic>> _forwardUsers = [];
  List<Map<String, dynamic>> _forwardChannels = [];
  Set<String> _selectedForwards = {}; // id_type e.g. '123_user'
  bool _isForwardLoading = false;

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
    // Polling for real-time messages (optimized interval)
    _startPolling();
  
  }

  /// Start polling for real-time messages
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _fetchMessages(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _searchGifs(String query) async {
    if (query.isEmpty) return;
    setState(() {
      _gifError = null;
      _gifResults = [];
    });
    try {
      final response = await http.get(
        Uri.parse('https://api.giphy.com/v1/gifs/search?api_key=$_giphyApiKey&q=$query&limit=20'),
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
   
      setState(() {
        _gifError = 'Error fetching GIFs.';
      });
    }
  }

  Future<void> _pickFile(String type) async {
    setState(() {
      _pickerError = null;
    });
    try {
      final picker = ImagePicker();
      XFile? picked;
      if (type == 'camera') {
        picked = await picker.pickImage(source: ImageSource.camera);
      } else if (type == 'gallery') {
        picked = await picker.pickImage(source: ImageSource.gallery);
      } else if (type == 'document') {
        picked = await picker.pickImage(source: ImageSource.gallery);
      }
      if (picked != null) {
        final captionController = TextEditingController();
        final shouldSend = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Send this image?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(picked!.path),
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
          setState(() {
            _pickedFile = File(picked!.path);
          });
          await _sendMediaMessage(File(picked!.path), captionController.text);
        }
      }
    } catch (e) {
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
          ApiConfig.uploadPrivateFileEndpoint,
        ),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Now send the message with the uploaded file
          final messageResponse = await http.post(
            Uri.parse(
              ApiConfig.sendPrivateMessageEndpoint,
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'type': 'media',
              'company_id': 1,
              'receiver_id': widget.userId,
              'content': caption,
              'media_ids': [
                {'file_path': data['file_path']},
              ],
              'reply_to_id': _replyTo != null ? _replyTo!['id'] : null,
            }),
          );

          if (messageResponse.statusCode == 200) {
            final messageData = json.decode(messageResponse.body);
            if (messageData['status'] == 'success') {
              setState(() {
                _pickedFile = null;
                _replyTo = null;
              });
              _fetchMessages(forceRefresh: true);
            }
          }
        }
      }
    } catch (e) {
    }
  }

  Future<void> _fetchMessages({bool loadMore = false, bool forceRefresh = false}) async {
    if (_isLoading || (!_hasMore && loadMore)) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final int fetchOffset = forceRefresh ? 0 : _offset;
     
      // Save current scroll position
      final double? currentScroll = _scrollController.hasClients ? _scrollController.position.pixels : null;
      
      // Save current last message id for comparison
      String? prevLastMsgId;
      if (forceRefresh && _groupedMessages.isNotEmpty) {
        final dateKeys = _groupedMessages.keys.toList()..sort((a, b) => _parseDate(b).compareTo(_parseDate(a)));
        final lastDate = dateKeys.isNotEmpty ? dateKeys.first : null;
        if (lastDate != null && _groupedMessages[lastDate]!.isNotEmpty) {
          prevLastMsgId = _groupedMessages[lastDate]!.first.id.toString();
        }
      }
      
      final newMessages = await MessageService.getChatMessages(
        chatId: widget.chatId ?? 0,
        limit: _limit,
        offset: fetchOffset,
      );
   
      
      if (newMessages.isEmpty || newMessages.values.every((list) => list.isEmpty)) {
        setState(() { _hasMore = false; });
    
      } else {
        setState(() {
          bool shouldScroll = false;
          if (forceRefresh) {
            // Keep track of all existing message IDs
            final Set<int> existingMessageIds = {};
            final Map<String, List<ChatMessage>> updatedGrouped = Map.from(_groupedMessages);
            
            // First collect all existing message IDs
            updatedGrouped.forEach((date, msgs) {
              existingMessageIds.addAll(msgs.map((msg) => msg.id));
            });
            
            // Process new messages
            newMessages.forEach((date, newMsgs) {
              
              // Filter out messages that already exist
              final List<ChatMessage> uniqueNewMsgs = newMsgs.where((newMsg) => !existingMessageIds.contains(newMsg.id)).toList();
              
              if (uniqueNewMsgs.isNotEmpty) {
              final oldMsgs = updatedGrouped[date] ?? [];
                // Merge and sort by time
                final List<ChatMessage> mergedList = [...uniqueNewMsgs, ...oldMsgs];
                mergedList.sort((a, b) => _parseTime(b.time).compareTo(_parseTime(a.time)));
              updatedGrouped[date] = mergedList;
                
                // Update the set with new message IDs
                existingMessageIds.addAll(uniqueNewMsgs.map((msg) => msg.id));
              }
            });
            
            _groupedMessages = updatedGrouped;
            
            // Get new last message id
            String? newLastMsgId;
            final dateKeys = newMessages.keys.toList()..sort((a, b) => _parseDate(b).compareTo(_parseDate(a)));
            final lastDate = dateKeys.isNotEmpty ? dateKeys.first : null;
            if (lastDate != null && newMessages[lastDate]!.isNotEmpty) {
              newLastMsgId = newMessages[lastDate]!.first.id.toString();
            }
            
            // Only scroll if there are new messages and user is already at bottom
            shouldScroll = (prevLastMsgId != null && newLastMsgId != null && prevLastMsgId != newLastMsgId) &&
                          (_scrollController.hasClients && _scrollController.position.pixels <= 100);
            
          
          } else {
            // Load more logic: append old messages at the end
            newMessages.forEach((date, msgs) {
              if (_groupedMessages.containsKey(date)) {
                // Filter out duplicates when loading more
                final existingIds = _groupedMessages[date]!.map((msg) => msg.id).toSet();
                final uniqueNewMsgs = msgs.where((msg) => !existingIds.contains(msg.id)).toList();
                
                if (uniqueNewMsgs.isNotEmpty) {
                  final List<ChatMessage> mergedList = [..._groupedMessages[date]!, ...uniqueNewMsgs];
                  // Sort by time
                  mergedList.sort((a, b) => _parseTime(b.time).compareTo(_parseTime(a.time)));
                  _groupedMessages[date] = mergedList;
                }
              } else {
                _groupedMessages[date] = msgs;
              }
            });
            _offset += _limit;
            shouldScroll = false; // Load more should not scroll
        
          }
          
          // Scroll only if new message and user is at bottom
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (shouldScroll && _scrollController.hasClients) {
              _scrollController.jumpTo(0);
            }
          });
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = e.toString(); });
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _initUserIdAndMessages() async {
    final id = await Storage.getUserId();
   
    setState(() {
      _currentUserId = id;
    });
 
    _fetchMessages();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <= 100 && _hasMore && !_isLoading) {
      _fetchMessages(loadMore: true);
    }
  }

  Future<void> _sendMessage({String? gifUrl}) async {
    if (_messageController.text.isEmpty && gifUrl == null) return;

    final token = await Storage.getToken();
    final message = gifUrl != null ? '<img src="$gifUrl" />' : _messageController.text.trim();

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.sendPrivateMessageEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'type': 'text',
          'company_id': 1,
          'receiver_id': widget.userId,
          'content': message,
          'reply_to_id': _replyTo != null ? _replyTo!['id'] : null,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _messageController.clear();
            _replyTo = null;
            _pickedFile = null;
            _showEmojiPicker = false;  // Close emoji panel
          });
          _fetchMessages(forceRefresh: true);
        }
      }
    } catch (e) {
    }
  }

  Future<void> _sendMessageWithContent(String content) async {
    if (content.trim().isEmpty) return;
    final receiverId = widget.userId;
    final companyId = 1;
    final now = DateTime.now();
    final replyToId = _replyTo != null ? _replyTo!['id'] : null;
   
    Map<String, dynamic>? tempReplyTo;
    if (_replyTo != null) {
      tempReplyTo = {
        'user_name': _replyTo!['senderName'],
        'content': _replyTo!['text'] ?? '',
        'has_media': _replyTo!['has_media'] ?? 0,
        'media_files': _replyTo!['media_files'] ?? [],
      };
    }
    final tempMsg = ChatMessage(
      id: -1,
      senderId: _currentUserId ?? 0,
      userName: 'You',
      userAvatar: '',
      content: content,
      time: DateFormat.jm().format(now),
      dateKey: 'Today',
      hasMedia: false,
      hasVoice: false,
      replyToId: replyToId,
      isForwarded: false,
      isEdited: false,
      isDeleted: false,
      isPinned: false,
      mediaFiles: [],
      voiceFile: null,
      voiceDuration: null,
      reactions: [],
      replyTo: tempReplyTo,
    );
    setState(() {
      final todayKey = 'Today';
      if (_groupedMessages.containsKey(todayKey)) {
        _groupedMessages[todayKey] = [tempMsg, ..._groupedMessages[todayKey]!];
      } else {
        _groupedMessages[todayKey] = [tempMsg];
      }
      _messageController.clear();
      _replyTo = null; // Clear reply state immediately
    });
    
    // Scroll to bottom only if user is already near bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.position.pixels <= 100) {
        _scrollController.jumpTo(0);
      }
    });
    
    try {
      final token = await Storage.getToken();
      final body = {
        'type': 'text',
        'company_id': companyId,
        'receiver_id': receiverId,
        'content': content,
        'reply_to_id': replyToId,
      };
   
      final response = await http.post(
        Uri.parse(ApiConfig.sendPrivateMessageEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Instead of fetching all messages, just update the temp message with real data
          final newMessage = ChatMessage.fromJson(data['data']);
          setState(() {
            final todayKey = 'Today';
            if (_groupedMessages.containsKey(todayKey)) {
              final index = _groupedMessages[todayKey]!.indexWhere((msg) => msg.id == -1);
              if (index != -1) {
                _groupedMessages[todayKey]![index] = newMessage;
              } else {
              }
            }
          });
        } else {
          if (!mounted) return;
          showThemedSnackbar(context, 'Message could not be sent. Please try again.', success: false);
          // Remove temp message on failure
          setState(() {
            final todayKey = 'Today';
            if (_groupedMessages.containsKey(todayKey)) {
              _groupedMessages[todayKey]!.removeWhere((msg) => msg.id == -1);
            }
          });
        }
      } else {
        if (!mounted) return;
        showThemedSnackbar(context, 'Server error. Please try again later.', success: false);
        // Remove temp message on failure
        setState(() {
          final todayKey = 'Today';
          if (_groupedMessages.containsKey(todayKey)) {
            _groupedMessages[todayKey]!.removeWhere((msg) => msg.id == -1);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      showThemedSnackbar(context, 'Something went wrong. Please try again.', success: false);
      // Remove temp message on failure
      setState(() {
        final todayKey = 'Today';
        if (_groupedMessages.containsKey(todayKey)) {
          _groupedMessages[todayKey]!.removeWhere((msg) => msg.id == -1);
        }
      });
    }
  }

  // Reaction add/remove API call
  Future<void> _addOrRemoveReaction(int messageId, String emoji) async {
    if (_currentUserId == null) {
      return;
    }
    
    final token = await Storage.getToken();
    try {
      // Log request data
      final requestBody = {
        'message_id': messageId,
        'emoji': emoji,
        'user_id': _currentUserId,
      };
      
      
      final response = await http.post(
        Uri.parse(ApiConfig.addReactionEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'success') {
          setState(() {
            _groupedMessages.forEach((date, msgs) {
              for (var i = 0; i < msgs.length; i++) {
                if (msgs[i].id == messageId) {
                  msgs[i] = ChatMessage(
                    id: msgs[i].id,
                    senderId: msgs[i].senderId,
                    userName: msgs[i].userName,
                    userAvatar: msgs[i].userAvatar,
                    content: msgs[i].content,
                    time: msgs[i].time,
                    dateKey: msgs[i].dateKey,
                    hasMedia: msgs[i].hasMedia,
                    hasVoice: msgs[i].hasVoice,
                    replyToId: msgs[i].replyToId,
                    isForwarded: msgs[i].isForwarded,
                    isEdited: msgs[i].isEdited,
                    isDeleted: msgs[i].isDeleted,
                    isPinned: msgs[i].isPinned,
                    mediaFiles: msgs[i].mediaFiles,
                    voiceFile: msgs[i].voiceFile,
                    voiceDuration: msgs[i].voiceDuration,
                    reactions: data['reactions'] ?? [],
                    replyTo: msgs[i].replyTo,
                  );
                  break;
                }
              }
            });
          });
        } else {
          if (!mounted) return;
          showThemedSnackbar(context, 'Could not update reaction. Please try again.', success: false);
        }
      } else {
        if (!mounted) return;
        showThemedSnackbar(context, 'Server error ${response.statusCode}. Please try again later.', success: false);
      }
    } catch (e) {
      if (!mounted) return;
      showThemedSnackbar(context, 'Something went wrong. Please try again.', success: false);
    }
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
          title: Container(
            height: kToolbarHeight,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(
                          userId: widget.userId,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFE0F2F1),
                        backgroundImage: widget.userAvatar.isNotEmpty ? NetworkImage(widget.userAvatar) : null,
                        child: widget.userAvatar.isEmpty
                            ? Text(widget.userName.isNotEmpty ? widget.userName[0] : '', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
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
                    builder: (context) => UserProfileScreen(
                      userId: widget.userId,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Simple white background
          Container(color: Colors.white),
          // Messages
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
                          'Oops! Unable to load chat messages.',
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
              child: _pickedFile != null ? Image.file(_pickedFile!, width: 100, height: 100) : SizedBox.shrink(),
          ),
          // Input Bar
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
                                      'Search for GIFs',
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
                                                      children: [
                                                        Expanded(
                                                          child: OutlinedButton(
                                                            onPressed: () => Navigator.pop(context),
                                                            style: OutlinedButton.styleFrom(
                                                              padding: const EdgeInsets.symmetric(vertical: 12),
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
                                        },
                                        child: Image.network(
                                          gif['images']['fixed_height_small']['url'],
                                          fit: BoxFit.cover,
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
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 16,
                                              offset: Offset(0, -2),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                        child: SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 4,
                                                margin: const EdgeInsets.only(bottom: 16, top: 8),
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
                              await _editMessage(_editingMessageId!, _messageController.text.trim());
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

    // Show loading indicator while initial messages are being fetched
    if (_isLoading && _offset == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    // Only show "No messages yet" if we're not loading and there are no messages
    if (!_isLoading && _groupedMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 60, color: AppTheme.primaryColor.withOpacity(0.3)),
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
      final messages = _groupedMessages[date];
      if (messages == null || messages.isEmpty) continue;
      
      messages.sort((a, b) => _parseTime(a.time).compareTo(_parseTime(b.time)));
      final messageWidgets = <Widget>[];
      for (int i = 0; i < messages.length; i++) {
        final msg = messages[i];
        if (msg == null) continue;
        
        double bottomMargin = 0;
        // Agar current message pe reaction hai, to neeche margin lagao
        if (msg.reactions != null && msg.reactions.isNotEmpty) {
          bottomMargin = 28; // Reaction ki height + thoda gap
        }
        messageWidgets.add(
          Container(
            margin: EdgeInsets.only(bottom: bottomMargin),
            child: _buildMessageBubble(msg),
          ),
        );
      }
      allMessages.add(Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDateHeader(date),
          ...messageWidgets.reversed,
        ],
      ));
    }

    if (_isLoading && _offset > 0) {
      allMessages.add(const Padding(
        padding: EdgeInsets.all(8.0),
        child: Center(child: CircularProgressIndicator()),
      ));
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

  Widget _buildMessageBubble(ChatMessage msg) {
    // Null safety checks
    if (msg == null) {
      return const SizedBox.shrink();
    }
    
    final bool isMe = _currentUserId != null && msg.senderId == _currentUserId;
    final String content = msg.content ?? '';
    final bool isHtml = content.isNotEmpty && RegExp(r'<(div|span|p|br|img|table|style|font|b|strong|a|ul|li|ol|h[1-6]|blockquote|pre|code|iframe|form|input|button|select|option|textarea|hr|em|i|u|s|strike|center|marquee|sup|sub|small|big|abbr|acronym|address|applet|area|article|aside|audio|base|basefont|bdi|bdo|bgsound|blink|body|canvas|caption|cite|col|colgroup|data|datalist|dd|del|details|dfn|dialog|dir|dl|dt|embed|fieldset|figcaption|figure|footer|frame|frameset|head|header|hgroup|html|ins|kbd|label|legend|link|main|map|mark|menu|menuitem|meta|meter|nav|noframes|noscript|object|optgroup|output|param|picture|portal|progress|q|rb|rp|rt|rtc|ruby|samp|script|section|shadow|slot|source|span|strike|style|summary|template|tbody|td|tfoot|th|thead|time|title|tr|track|tt|var|video|wbr)[\s>]').hasMatch(content);
    final bool isBase64Img = content.isNotEmpty && content.contains('<img') && content.contains('src="data:image/');
    final isGif = content.isNotEmpty && (content.trim().endsWith('.gif') || 
                 content.contains('giphy.com/media/') ||
                 content.contains('tenor.com/view/') ||
                 content.contains('media.giphy.com/media/') ||
                 content.contains('media.tenor.com/'));

    final imageFiles = msg.hasMedia && msg.mediaFiles != null && msg.mediaFiles.isNotEmpty
        ? msg.mediaFiles.where((file) => file is Map && file['file_path'] != null && (file['file_type'] == 'image' || file['file_type'] == null)).toList()
        : <dynamic>[];
    final docFiles = msg.hasMedia && msg.mediaFiles != null && msg.mediaFiles.isNotEmpty
        ? msg.mediaFiles.where((file) => file is Map && file['file_path'] != null && file['file_type'] == 'document').toList()
        : <dynamic>[];
    final bool hasMedia = imageFiles.isNotEmpty || docFiles.isNotEmpty;

    List<Widget> contentWidgets = [];
    
    // WhatsApp-style forwarded label
    if (msg.isForwarded) {
      contentWidgets.insert(0, Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.reply, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              'Forwarded',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ));
    }

    // WhatsApp-style reply bubble
    if (msg.replyTo != null) {
      final reply = msg.replyTo!;
      // Agar forwarded label bhi hai to reply bubble ko index 1 par, warna 0 par
      final replyIndex = msg.isForwarded && contentWidgets.isNotEmpty ? 1 : 0;
      contentWidgets.insert(replyIndex, Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
                    color: Colors.grey[100],
          border: Border(
            left: BorderSide(color: AppTheme.primaryColor, width: 4),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reply['user_name'] ?? '',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13),
            ),
            const SizedBox(height: 2),
            if ((reply['has_media'] ?? 0) == 1 && reply['media_files'] != null && reply['media_files'].isNotEmpty)
              Row(
                children: [
                  Icon(Icons.image, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Media', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
              ),
            if ((reply['content'] ?? '').isNotEmpty)
              Text(
                reply['content'],
                style: TextStyle(fontSize: 13, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                          ),
          ],
                    ),
      ));
    }

    // Add text/HTML content if exists, lekin agar image bhi hai to yahan text na add karo
    if (content.isNotEmpty && !isGif && !isBase64Img && imageFiles.isEmpty) {
      contentWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: isHtml
              ? Container(
                  constraints: BoxConstraints(
                    maxHeight: 300,
                    minHeight: 0,
                  ),
                  child: SingleChildScrollView(
                    child: Html(
                      data: sanitizeHtml(content),
                      style: {
                        "h1": Style(fontSize: FontSize(22), fontWeight: FontWeight.bold),
                        "h2": Style(fontSize: FontSize(20), fontWeight: FontWeight.bold),
                        "h3": Style(fontSize: FontSize(18), fontWeight: FontWeight.bold),
                        "p": Style(fontSize: FontSize(16)),
                        "div": Style(fontSize: FontSize(16)),
                      },
                    ),
                  ),
                )
              : Text(
                  decodeHtmlEntities(content),
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                            ),
                          ),
                        );
    }

    // Prepare reactions widget (if any)
    Widget? reactionsWidget;
    if (msg.reactions != null && msg.reactions.isNotEmpty) {
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
            if (reaction == null) return const SizedBox.shrink();
            final emoji = reaction['emoji'] ?? '';
            final count = reaction['count'] ?? 1;
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

    // Add media content if exists
    if (msg.hasMedia && msg.mediaFiles != null && msg.mediaFiles.isNotEmpty) {
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
                                          'url': getFullImageUrl(file['file_path']),
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
                      getFullImageUrl(file['file_path']),
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
              if (content.isNotEmpty && !isGif && !isBase64Img)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                  child: isHtml
                      ? Container(
                          constraints: BoxConstraints(
                            maxHeight: 300,
                            minHeight: 0,
                          ),
                          child: SingleChildScrollView(
                            child: Html(
                              data: sanitizeHtml(content),
                              style: {
                                "h1": Style(fontSize: FontSize(22), fontWeight: FontWeight.bold),
                                "h2": Style(fontSize: FontSize(20), fontWeight: FontWeight.bold),
                                "h3": Style(fontSize: FontSize(18), fontWeight: FontWeight.bold),
                                "p": Style(fontSize: FontSize(16)),
                                "div": Style(fontSize: FontSize(16)),
                              },
                            ),
                          ),
                        )
                      : Text(
                          decodeHtmlEntities(content),
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                ),
            ],
          );
          contentWidgets.add(mediaWidget);
        } else if (imageFiles.length == 2) {
          // 2 images
          mediaWidget = Row(
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
                                            'url': getFullImageUrl(file['file_path']),
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
                                getFullImageUrl(file['file_path']),
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
          );
          contentWidgets.add(mediaWidget);
        } else {
          // 3 or more images
          int showCount = imageFiles.length > 4 ? 4 : imageFiles.length;
          mediaWidget = GridView.builder(
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
                                    'url': getFullImageUrl(file['file_path']),
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
                        getFullImageUrl(file['file_path']),
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
              if (index == 3 && imageFiles.length > 4) {
                int moreCount = imageFiles.length - 4;
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
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '+$moreCount more',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return img;
            },
          );
          contentWidgets.add(mediaWidget);
        }
      }

      if (docFiles.isNotEmpty) {
        contentWidgets.add(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: docFiles.map<Widget>((file) {
                    return GestureDetector(
                      onTap: () async {
                        final url = getFullImageUrl(file['file_path']);
                  final fileName = (file['media_name'] ?? 'Document').toString();
                  if (fileName.toLowerCase().endsWith('.pdf')) {
                    // Try in-app PDF preview first
                    try {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PdfViewerScreen(
                            url: url,
                            title: file['media_name'] ?? 'Document',
                          ),
                        ),
                      );
                    } catch (e) {
                        final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No app found to open this file.')),
                        );
                      }
                    }
                  } else {
                    // Word, Excel, etc.: Download to Downloads or app storage
                    try {
                      var status = await Permission.storage.request();
                      if (status.isDenied || status.isPermanentlyDenied) {
                        status = await Permission.manageExternalStorage.request();
                      }
                      bool canUseDownloads = status.isGranted;
                      String localPath = '';
                      if (canUseDownloads) {
                        final downloadsDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
                        final downloadsDir = downloadsDirs != null && downloadsDirs.isNotEmpty ? downloadsDirs.first : null;
                        if (downloadsDir != null) {
                          localPath = '${downloadsDir.path}/$fileName';
                        }
                      }
                      if (localPath.isEmpty) {
                        final appDir = await getExternalStorageDirectory();
                        if (appDir == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No storage directory found.')),
                          );
                          return;
                        }
                        localPath = '${appDir.path}/$fileName';
                      }
                      // Download file first
                      final response = await http.get(Uri.parse(url));
                      if (response.statusCode == 200) {
                        final f = File(localPath);
                        await f.writeAsBytes(response.bodyBytes);
                        // Show snackbar after successful download
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.download_done, color: Colors.teal, size: 26),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        canUseDownloads
                                          ? 'File downloaded to Downloads'
                                          : 'File saved in app storage (not in Downloads)',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15),
                                      ),
                                      Text(
                                        fileName,
                                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (!canUseDownloads)
                                        const Text(
                                          'Use Open to view.',
                                          style: TextStyle(fontSize: 12, color: Colors.black54),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            action: SnackBarAction(
                              label: 'Open',
                              onPressed: () async {
                                final result = await OpenFile.open(localPath);
                                if (result.type != ResultType.done) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Could not open file: ${result.message}')),
                                  );
                                }
                              },
                            ),
                            duration: const Duration(seconds: 6),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('File download failed.')),
                            );
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                          );
                    }
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.insert_drive_file, color: Colors.blueAccent),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                file['media_name'] ?? 'Document',
                                style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        );
      }
    } else if (isGif) {
      String gifUrl = content;
      if (content.contains('<img')) {
        final imgReg = RegExp(r'src="([^"]+)"');
        final match = imgReg.firstMatch(content);
        if (match != null) {
          gifUrl = match.group(1)!;
      }
      }
      contentWidgets.add(
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
      );
    } else if (isBase64Img) {
      final base64Reg = RegExp(r'src="data:image/[^;]+;base64,([^"]+)"');
      final match = base64Reg.firstMatch(content);
      if (match != null) {
        final base64Str = match.group(1)!;
        final bytes = base64Decode(base64Str);
        contentWidgets.add(
          GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.black,
                insetPadding: const EdgeInsets.all(0),
                child: _ImagePreviewSlider(
                  mediaList: [
                    {
                      'url': content,
                      'sender': msg.userName,
                    }
                  ],
                  initialIndex: 0,
                ),
              ),
            );
          },
          child: Image.memory(bytes, width: 180, height: 180, fit: BoxFit.cover),
        ),
      );
      }
    }

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isMe) const SizedBox(width: 2),
        Flexible(
          child: GestureDetector(
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
                                'text': content,
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
                              _editingOriginalText = content;
                              _messageController.text = content;
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
                              _ReactionIcon('❤️',
                                isActive: msg.reactions.any((r) => r['emoji'] == '❤️' && r['is_reacted'] == 1),
                                onTap: () {
                                Navigator.pop(context);
                                  _addOrRemoveReaction(msg.id, '❤️');
                                },
                              ),
                              _ReactionIcon('👍',
                                isActive: msg.reactions.any((r) => r['emoji'] == '👍' && r['is_reacted'] == 1),
                                onTap: () {
                                Navigator.pop(context);
                                  _addOrRemoveReaction(msg.id, '👍');
                                },
                              ),
                              _ReactionIcon('😂',
                                isActive: msg.reactions.any((r) => r['emoji'] == '😂' && r['is_reacted'] == 1),
                                onTap: () {
                                Navigator.pop(context);
                                  _addOrRemoveReaction(msg.id, '😂');
                                },
                              ),
                              _ReactionIcon('😮',
                                isActive: msg.reactions.any((r) => r['emoji'] == '😮' && r['is_reacted'] == 1),
                                onTap: () {
                                Navigator.pop(context);
                                  _addOrRemoveReaction(msg.id, '😮');
                                },
                              ),
                              _ReactionIcon('😢',
                                isActive: msg.reactions.any((r) => r['emoji'] == '😢' && r['is_reacted'] == 1),
                                onTap: () {
                                Navigator.pop(context);
                                  _addOrRemoveReaction(msg.id, '😢');
                                },
                              ),
                              _ReactionIcon('🙏',
                                isActive: msg.reactions.any((r) => r['emoji'] == '🙏' && r['is_reacted'] == 1),
                                onTap: () {
                                Navigator.pop(context);
                                  _addOrRemoveReaction(msg.id, '🙏');
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
            padding: imageFiles.isNotEmpty
                ? const EdgeInsets.symmetric(vertical: 6, horizontal: 0)
                : const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
              minWidth: 0,
              minHeight: 0,
              ),
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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...contentWidgets,
                      const SizedBox(height: 4),
                      Text(
                        msg.time + (msg.isEdited == true ? '  edited' : ''),
                        style: TextStyle(
                          color: Colors.black38,
                          fontSize: 12,
                          fontStyle: msg.isEdited == true ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ],
                  ),
                  if (reactionsWidget != null)
                    Positioned(
                      bottom: -25,
                      right: isMe ? -10 : null,
                      left: isMe ? null : -10,
                      child: SizedBox(
                        height: 28,
                        child: reactionsWidget,
                      ),
                    ),
                ],
              ),
            ),
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
          child: Text(date, style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
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

  // Helper function to decode HTML entities in plain text
  String decodeHtmlEntities(String text) {
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  // Helper function to sanitize HTML (remove extra div/span/style/script)
  String sanitizeHtml(String html) {
    final document = html_parser.parse(html);
    // Remove all style and script tags
    document.querySelectorAll('style, script').forEach((element) => element.remove());
    // Remove all attributes except href from <a>
    document.body!.querySelectorAll('*').forEach((element) {
      if (element.localName == 'a') {
        element.attributes.removeWhere((key, value) => key != 'href');
      } else {
        element.attributes.clear();
      }
    });
    return document.body!.innerHtml;
  }

  // Helper function to parse time string (e.g. "11:05 PM")
  DateTime _parseTime(String time) {
    final now = DateTime.now();
    try {
      final format = DateFormat.jm();
      final parsed = format.parse(time);
      // Return with today's date to avoid compare error
      return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    } catch (e) {
      return now;
    }
  }

  // Helper function to parse dateKey string
  DateTime _parseDate(String key) {
    if (key == 'Today') return DateTime.now();
    if (key == 'Yesterday') return DateTime.now().subtract(Duration(days: 1));
    try {
      return DateFormat('MMMM d, yyyy').parse(key);
    } catch (e) {
      return DateTime(1970);
    }
  }

  String getFullImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    String cleanPath = path.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
    return ApiConfig.getAssetUrl(cleanPath);
  }

  Future<void> _editMessage(int messageId, String newContent) async {
    final token = await Storage.getToken();
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.editPrivateMessageEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message_id': messageId,
          'content': newContent,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Update message in _groupedMessages
          setState(() {
            _groupedMessages.forEach((date, msgs) {
              for (var i = 0; i < msgs.length; i++) {
                if (msgs[i].id == messageId) {
                  msgs[i] = ChatMessage(
                    id: msgs[i].id,
                    senderId: msgs[i].senderId,
                    userName: msgs[i].userName,
                    userAvatar: msgs[i].userAvatar,
                    content: data['data']['message'],
                    time: data['data']['time'],
                    dateKey: msgs[i].dateKey,
                    hasMedia: msgs[i].hasMedia,
                    hasVoice: msgs[i].hasVoice,
                    replyToId: msgs[i].replyToId,
                    isForwarded: msgs[i].isForwarded,
                    isEdited: true,
                    isDeleted: msgs[i].isDeleted,
                    isPinned: msgs[i].isPinned,
                    mediaFiles: data['data']['media_files'] ?? [],
                    voiceFile: msgs[i].voiceFile,
                    voiceDuration: msgs[i].voiceDuration,
                    reactions: msgs[i].reactions,
                    replyTo: msgs[i].replyTo,
                  );
                  break;
                }
              }
            });
          });
        } else {
          if (!mounted) return;
          showThemedSnackbar(context, 'Edit failed: ${data['message'] ?? 'Unknown error'}', success: false);
        }
      } else {
        if (!mounted) return;
        showThemedSnackbar(context, 'Server error: ${response.statusCode}', success: false);
      }
    } catch (e) {
      if (!mounted) return;
      showThemedSnackbar(context, 'Something went wrong: $e', success: false);
    }
  }

  // Add _showForwardModal function:
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
        Uri.parse(ApiConfig.getForwardListEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _forwardUsers = List<Map<String, dynamic>>.from(data['data']['users'] ?? []);
            _forwardChannels = List<Map<String, dynamic>>.from(data['data']['channels'] ?? []);
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
    ChatMessage? forwardMsg;
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
            // Filtered lists
            final filteredUsers = _forwardUsers.where((user) {
              final name = ('${user['first_name']} ${user['last_name'] ?? ''}').toLowerCase();
              return name.contains(searchText.toLowerCase());
            }).toList();
            final filteredChannels = _forwardChannels.where((ch) {
              final name = (ch['name'] ?? '').toLowerCase();
              return name.contains(searchText.toLowerCase());
            }).toList();
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 540,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Forwarding message:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    if (forwardMsg != null)
                      _ForwardMessagePreview(forwardMsg!),
                    const Divider(height: 28),
                    // Search bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search users or channels...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      ),
                      onChanged: (val) => setModalState(() => searchText = val),
                    ),
                    const SizedBox(height: 12),
                    const Text('Forward to', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _isForwardLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              children: [
                                if (filteredUsers.isNotEmpty)
                                  ...[
                                    const Text('Users', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ...filteredUsers.map((user) => CheckboxListTile(
                                          value: _selectedForwards.contains('${user['id']}_user'),
                                          onChanged: (val) {
                                            setModalState(() {
                                              if (val == true) {
                                                _selectedForwards.add('${user['id']}_user');
                                              } else {
                                                _selectedForwards.remove('${user['id']}_user');
                                              }
                                            });
                                          },
                                          title: Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundImage: user['profile_picture'] != null && user['profile_picture'].toString().isNotEmpty
                                                    ? NetworkImage(ApiConfig.getAssetUrl(user['profile_picture']))
                                                    : null,
                                                child: user['profile_picture'] == null || user['profile_picture'].toString().isEmpty
                                                    ? Text(user['first_name']?[0] ?? '?')
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Text('${user['first_name']} ${user['last_name'] ?? ''}'),
                                              const SizedBox(width: 8),
                                              if (user['status'] == 'online')
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        )),
                                  ],
                                if (filteredChannels.isNotEmpty)
                                  ...[
                                    const SizedBox(height: 16),
                                    const Text('Channels', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ...filteredChannels.map((ch) => CheckboxListTile(
                                          value: _selectedForwards.contains('${ch['id']}_channel'),
                                          onChanged: (val) {
                                            setModalState(() {
                                              if (val == true) {
                                                _selectedForwards.add('${ch['id']}_channel');
                                              } else {
                                                _selectedForwards.remove('${ch['id']}_channel');
                                              }
                                            });
                                          },
                                          title: Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundImage: ch['profile_picture'] != null && ch['profile_picture'].toString().isNotEmpty
                                                    ? NetworkImage(ApiConfig.getAssetUrl(ch['profile_picture']))
                                                    : null,
                                                child: ch['profile_picture'] == null || ch['profile_picture'].toString().isEmpty
                                                    ? Text(ch['name']?[0] ?? '?')
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(ch['name'] ?? ''),
                                              const SizedBox(width: 8),
                                              Text('(${ch['member_count'] ?? 0} members)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                        )),
                                  ],
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 120,
                          child: ElevatedButton(
                            onPressed: _selectedForwards.isEmpty || isForwarding
                                ? null
                                : () async {
                                    setModalState(() => isForwarding = true);
                                    final forwardTo = _selectedForwards.map((s) {
                                      final parts = s.split('_');
                                      return {'id': int.parse(parts[0]), 'type': parts[1]};
                                    }).toList();
                                  
                                    final token = await Storage.getToken();
                                    final body = {
                                      'message_id': messageId,
                                      'forward_to': forwardTo,
                                    };
                               
                                    final response = await http.post(
                                      Uri.parse(ApiConfig.forwardMessageEndpoint),
                                      headers: {
                                        'Authorization': 'Bearer $token',
                                        'Content-Type': 'application/json',
                                      },
                                      body: json.encode(body),
                                    );
                               
                                    setModalState(() => isForwarding = false);
                                    if (response.statusCode == 200) {
                                      final data = json.decode(response.body);
                                      if (data['status'] == 'success') {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                            child: isForwarding
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
    final token = await Storage.getToken();
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.deletePrivateMessageEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message_id': messageId,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            _groupedMessages.forEach((date, msgs) {
              msgs.removeWhere((m) => m.id == messageId);
            });
          });
        } else {
          if (!mounted) return;
          showThemedSnackbar(context, 'Delete failed: ${data['message'] ?? 'Unknown error'}', success: false);
        }
      } else {
        if (!mounted) return;
        showThemedSnackbar(context, 'Server error: ${response.statusCode}', success: false);
      }
    } catch (e) {
      if (!mounted) return;
      showThemedSnackbar(context, 'Something went wrong: $e', success: false);
    }
  }

  // User-friendly snackbar for errors/success
  void showThemedSnackbar(BuildContext context, String message, {bool success = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = success
        ? (isDark ? Colors.green[700] : Colors.green[400])
        : (isDark ? Colors.red[700] : Colors.red[400]);
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
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionIcon({required this.icon, required this.label, required this.color, required this.onTap});

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
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ReactionIcon extends StatelessWidget {
  final String emoji;
  final VoidCallback onTap;
  final bool isActive;
  const _ReactionIcon(this.emoji, {required this.onTap, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          decoration: isActive
              ? BoxDecoration(
                  color: Colors.blue.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue, width: 2),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
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
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewSlider extends StatefulWidget {
  final List<Map<String, String>> mediaList;
  final int initialIndex;
  const _ImagePreviewSlider({Key? key, required this.mediaList, required this.initialIndex}) : super(key: key);

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
          onPageChanged: (i) {
            if (mounted) {
              setState(() => _currentIndex = i);
            }
          },
          itemBuilder: (context, index) {
            return Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: AspectRatio(
                      aspectRatio: 9 / 16,
                      child: Image.network(
                        widget.mediaList[index]['url']!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.broken_image, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 30,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.mediaList[index]['sender'] ?? '',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        Positioned(
          top: 30,
          right: 20,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        if (_currentIndex > 0)
          Positioned(
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 32),
              onPressed: () {
                if (_currentIndex > 0) {
                  _controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
            ),
          ),
        if (_currentIndex < widget.mediaList.length - 1)
          Positioned(
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 32),
              onPressed: () {
                if (_currentIndex < widget.mediaList.length - 1) {
                  _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
            ),
          ),
        Positioned(
          bottom: 30,
          child: Text(
            '${_currentIndex + 1} / ${widget.mediaList.length}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
} 

// Add this widget at the end of the file:
class _ForwardMessagePreview extends StatelessWidget {
  final ChatMessage msg;
  const _ForwardMessagePreview(this.msg);

  @override
  Widget build(BuildContext context) {
    final bool isMedia = msg.hasMedia && msg.mediaFiles.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!)),
      child: isMedia
          ? Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: msg.mediaFiles != null && msg.mediaFiles.isNotEmpty && msg.mediaFiles[0] != null
                      ? Image.network(
                          msg.mediaFiles[0]['file_path'].toString().startsWith('http')
                              ? msg.mediaFiles[0]['file_path']
                              : ApiConfig.getAssetUrl(msg.mediaFiles[0]['file_path']),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                      : const SizedBox(width: 60, height: 60),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg.content?.isNotEmpty == true ? msg.content! : 'Media',
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          : Text(
              msg.content ?? '',
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
} 
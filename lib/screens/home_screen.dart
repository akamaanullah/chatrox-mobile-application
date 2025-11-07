import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../config/api_config.dart';
import 'chat_screen.dart';
import 'activity_screen.dart';
import 'channels_screen.dart';
import 'profile_screen.dart';
import 'edit_name_screen.dart';
import 'edit_about_screen.dart';
import 'edit_links_screen.dart';
import 'settings_screen.dart';
import 'starred_messages_screen.dart';
import 'all_contacts_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'select_contacts_for_media_screen.dart';
import '../models/recent_message.dart';
import '../services/message_service.dart';
import '../widgets/recent_messages_list.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'channel_chat_screen.dart';
import '../services/notification_service.dart';
import 'package:http/http.dart' as http;
import '../utils/storage.dart';
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  File? _pickedFile;
  String? _pickerError;

  List<RecentMessage> _messages = [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollingTimer;

  int _totalUnreadActivities = 0;

  String _searchQuery = '';

  // Add screens for bottom navigation
  final List<Widget> _screens = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _screens.addAll([
      _buildChatsScreen(),
      const ActivityScreen(),
      const ChannelsScreen(),
      const ProfileScreen(),
    ]);
    _loadMessages();
    _startPolling();
    NotificationService().startPolling();
    _loadActivitiesUnreadCount();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Optimized polling interval - will be replaced with WebSocket when ready
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_selectedIndex == 0) {
        _loadMessages();
      }
      _loadActivitiesUnreadCount();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    NotificationService().stopPolling();
    super.dispose();
  }

  Future<void> _pickCamera() async {
    setState(() {
      _pickerError = null;
    });
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.camera);
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
                      File(picked.path),
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SelectContactsForMediaScreen(
                imageFile: File(picked.path),
                caption: captionController.text,
                              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _pickerError = e.toString();
      });
    }
  }

  Widget _buildChatsScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FBFB), Color(0xFFE8F5F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
                              ),
                            ),
        child: Column(
                          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(30),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search messages',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      : RecentMessagesList(
                          messages: _messages,
                          onTap: (message) {
                            if (message.conversationType == 'channel') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChannelChatScreen(
                                    channelName: message.channelName ?? 'Unknown Channel',
                                    channelDescription: 'No description',
                                    channelAvatar: message.channelAvatar ?? '',
                                    channelId: message.conversationId,
                                    isPrivate: false,
                                    membersCount: 0,
                                    ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    userName: message.displayName,
                                    userAvatar: message.avatarUrl,
                                    chatId: message.conversationId,
                                    userId: message.userId,
                                  ),
                                ),
                              );
                            }
                          },
                                ),
                              ),
                          ],
                        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickCamera,
        child: const Icon(Icons.camera_alt),
        backgroundColor: AppTheme.secondaryColor,
      ),
    );
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await MessageService.getRecentMessages();
      if (!listEquals(_messages, messages)) {
        setState(() {
          _messages = messages;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handleMessageTap(RecentMessage message) async {
    print('Message Type: \\${message.conversationType}'); // Debug print
    print('Channel Name: \\${message.channelName}'); // Debug print
    print('Conversation ID: \\${message.conversationId}'); // Debug print

    // Mark as read API call
    final token = await Storage.getToken();
    if (message.conversationType == 'channel') {
      // Channel message
      await http.post(
        Uri.parse(ApiConfig.markChannelReadEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: '{"channel_id": ${message.conversationId}, "message_id": ${message.lastMessageId}}',
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChannelChatScreen(
            channelName: message.channelName ?? 'Unknown Channel',
            channelDescription: 'No description',
            channelAvatar: message.channelAvatar ?? '',
            channelId: message.conversationId,
            isPrivate: false,
            membersCount: 0,
                    ),
                  ),
                );
    } else {
      // Private message
      await http.post(
        Uri.parse(ApiConfig.markPrivateReadEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: '{"conversation_id": ${message.conversationId}, "message_id": ${message.lastMessageId}}',
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            userName: message.displayName,
            userAvatar: message.avatarUrl,
            chatId: message.conversationId,
            userId: message.userId,
            ),
          ),
    );
    }
  }

  Future<void> _loadActivitiesUnreadCount() async {
    try {
      final token = await Storage.getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.getActivitiesEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final unreadCount = data['data']['unread_count'] ?? 0;
          setState(() {
            _totalUnreadActivities = unreadCount;
          });
        }
      }
    } catch (e) {
      // ignore error
    }
  }

  Future<void> _markAllNotificationsAsRead() async {
    try {
      final token = await Storage.getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.markAsReadEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: '{"all": true}',
      );
      // Optionally, check response and show snackbar
      await _loadActivitiesUnreadCount();
    } catch (e) {
      // Optionally, show error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Modern gradient background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F5F4), Color(0xFFF8FBFB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Modern AppBar with gradient
            Container(
              padding: const EdgeInsets.fromLTRB(0, 28, 0, 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.13),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedIndex == 0
                          ? 'Chatrox'
                          : _selectedIndex == 1
                              ? 'Activity'
                              : _selectedIndex == 2
                                  ? 'Channels'
                                  : 'Profile',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        letterSpacing: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedIndex == 0)
                      Row(
                        children: [
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: Colors.white),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            color: Colors.white,
                            elevation: 8,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'new_channel',
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.secondaryColor.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(Icons.add_circle_outline, color: AppTheme.secondaryColor, size: 22),
                                    ),
                                    const SizedBox(width: 14),
                                    const Text('New Channel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'profile',
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(Icons.person_outline, color: AppTheme.primaryColor, size: 22),
                                    ),
                                    const SizedBox(width: 14),
                                    const Text('Profile', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'settings',
                                child: Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(Icons.settings, color: AppTheme.primaryColor, size: 22),
                                    ),
                                    const SizedBox(width: 14),
                                    const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'new_channel') {
                                setState(() {
                                  _selectedIndex = 2;
                                });
                              } else if (value == 'profile') {
                                setState(() {
                                  _selectedIndex = 3;
                                });
                              } else if (value == 'settings') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            // Search Bar
            if (_selectedIndex == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.white.withOpacity(0.85),
                  child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search or start new chat',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.18)),
                          ),
                          prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: Colors.grey[500]),
                                  onPressed: () {
                                      _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                  ),
                ),
              ),
            // Chat List
            if (_selectedIndex == 0)
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadMessages,
                  child: _buildBody(),
                ),
              ),
            // Agar dusre tabs hain to unka widget yahan dikhayein
            if (_selectedIndex != 0)
              Expanded(child: _screens[_selectedIndex]),
            // Show picked image and error (optional, for testing)
            if (_pickedFile != null)
              Positioned(
                top: 120,
                left: 20,
                child: Image.file(_pickedFile!, width: 100, height: 100),
              ),
            if (_pickerError != null)
              Positioned(
                top: 230,
                left: 20,
                child: Text(_pickerError!, style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const AllContactsScreen()));
        },
        backgroundColor: AppTheme.secondaryColor,
        child: const Icon(Icons.contacts),
      ) : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.secondaryColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) async {
            setState(() {
              _selectedIndex = index;
            });
            if (index == 1) {
              await _markAllNotificationsAsRead();
            }
          },
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withOpacity(0.7),
          backgroundColor: Colors.transparent,
            elevation: 0,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            items: [
            BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 0 ? Colors.white.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_selectedIndex == 0 ? Icons.chat_bubble : Icons.chat_bubble_outline),
                    ),
                    if (_totalUnreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            _totalUnreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 1 ? Colors.white.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_selectedIndex == 1 ? Icons.notifications_active : Icons.notifications_active_outlined),
                    ),
                    if (_totalUnreadActivities > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            _totalUnreadActivities.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              label: 'Activity',
            ),
            BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 2 ? Colors.white.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_selectedIndex == 2 ? Icons.groups_2 : Icons.groups_2_outlined),
                ),
              label: 'Channels',
            ),
            BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 3 ? Colors.white.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_selectedIndex == 3 ? Icons.person : Icons.person_outline),
                ),
              label: 'Profile',
            ),
          ],
          type: BottomNavigationBarType.fixed,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.secondaryColor,
        ),
      );
    }

    if (_error != null) {
      return Center(
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
              'Oops! Unable to load messages.',
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
                color: Colors.grey[700],
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh, color: Colors.white),
              label: Text('Try Again', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _loadMessages,
            ),
          ],
        ),
      );
    }

    List<RecentMessage> filteredMessages = _messages;
    if (_searchQuery.isNotEmpty) {
      filteredMessages = _messages.where((msg) =>
        msg.displayName.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (filteredMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new conversation',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RecentMessagesList(
      messages: filteredMessages,
      onTap: _handleMessageTap,
    );
  }

  int get _totalUnreadCount {
    return _messages.fold(0, (sum, msg) => sum + (msg.unreadCount ?? 0));
  }
} 
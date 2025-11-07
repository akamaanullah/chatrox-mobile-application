import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../config/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_html/flutter_html.dart';
import '../utils/storage.dart';
import '../screens/channel_profile_screen.dart' show showThemedSnackbar;

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<Map<String, dynamic>> notifications = [];
  List<Map<String, dynamic>> announcements = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        setState(() {
          _error = 'Not logged in';
          _isLoading = false;
        });
        return;
      }
      final url = Uri.parse(
        ApiConfig.getActivitiesEndpoint,
      );
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        final allNotifications = List<Map<String, dynamic>>.from(
          data['data']['notifications'] ?? [],
        );
        
        // Separate announcements from regular notifications
        List<Map<String, dynamic>> regularNotifications = [];
        List<Map<String, dynamic>> announcementNotifications = [];
        
        for (var notification in allNotifications) {
          if (notification['type'] == 'announcement') {
            announcementNotifications.add(notification);
          } else {
            regularNotifications.add(notification);
          }
        }
        
        setState(() {
          notifications = regularNotifications;
          announcements = announcementNotifications;
          _isLoading = false;
        });
        
        print('DEBUG: Regular notifications: ${notifications.length}');
        print('DEBUG: Announcement notifications: ${announcements.length}');
      } else {
        setState(() {
          _error = data['message'] ?? 'Failed to load activities';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color getTypeColor(String type) {
    switch (type) {
      case 'mention':
        return AppTheme.secondaryColor;
      case 'accepted':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade400;
      case 'join_request':
        return Colors.blue.shade400;
      case 'announcement':
        return Colors.orange.shade600;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData getTypeIcon(String type) {
    switch (type) {
      case 'mention':
        return Icons.alternate_email_rounded;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'join_request':
        return Icons.group_add_rounded;
      case 'announcement':
        return Icons.announcement_rounded;
      default:
        return Icons.notifications;
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Delete Notification'),
                content: const Text(
                  'Are you sure you want to delete this notification?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _handleJoinRequestAction(int index, bool accepted) async {
    final notif = notifications[index];
    final notifId = notif['id'];
    if (notifId == null) {
      showThemedSnackbar(
        context,
        'Invalid request: No notification id found!',
        success: false,
      );
      return;
    }
    setState(() {
      notifications[index]['_loading'] = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final channelId = notif['reference_id'];
      if (channelId == null) {
        showThemedSnackbar(
          context,
          'Invalid request: No channel id found!',
          success: false,
        );
        return;
      }
      final url = Uri.parse(
        accepted
                    ? ApiConfig.acceptRequestEndpoint
        : ApiConfig.rejectRequestEndpoint,
      );
      final body = json.encode({'channel_id': channelId});
      print('API CALL: ${url.toString()}');
      print('Request Body: ' + body);
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          notifications[index]['type'] = accepted ? 'accepted' : 'rejected';
          notifications[index]['_loading'] = false;
        });
        showThemedSnackbar(
          context,
          accepted ? 'Request accepted' : 'Request rejected',
          success: true,
        );
      } else {
        setState(() {
          notifications[index]['_loading'] = false;
        });
        showThemedSnackbar(
          context,
          data['message'] ?? 'Failed to process request!',
          success: false,
        );
      }
    } catch (e) {
      setState(() {
        notifications[index]['_loading'] = false;
      });
      print('Error: $e');
      showThemedSnackbar(context, 'Error: $e', success: false);
    }
  }

  Future<bool> _deleteNotification(int notifId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final url = Uri.parse(
        ApiConfig.deleteNotificationEndpoint,
      );
      final body = json.encode({'notification_id': notifId});
      print('API CALL: ${url.toString()}');
      print('Request Body: ' + body);
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return true;
      } else {
        showThemedSnackbar(
          context,
          data['message'] ?? 'Failed to delete notification!',
          success: false,
        );
        return false;
      }
    } catch (e) {
      print('Error: $e');
      showThemedSnackbar(context, 'Error: $e', success: false);
      return false;
    }
  }

  Future<bool> _deleteAnnouncement(int announcementId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final url = Uri.parse(
        ApiConfig.deleteAnnouncementEndpoint,
      );
      final body = json.encode({'announcement_id': announcementId});
      print('API CALL: ${url.toString()}');
      print('Request Body: ' + body);
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        return true;
      } else {
        showThemedSnackbar(
          context,
          data['message'] ?? 'Failed to delete announcement!',
          success: false,
        );
        return false;
      }
    } catch (e) {
      print('Error: $e');
      showThemedSnackbar(context, 'Error: $e', success: false);
      return false;
    }
  }

  Widget _buildAnnouncementItem(Map<String, dynamic> announcement) {
    final title = announcement['message_content'] ?? 'Announcement';
    final channelName = announcement['channel_name'] ?? '';
    final timeAgo = announcement['time_ago'] ?? '';
    final createdAt = announcement['created_at'] ?? '';

    return Dismissible(
      key: ValueKey('announcement_${announcement['id']}'),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) => _confirmDelete(context),
      onDismissed: (direction) async {
        final announcementId = announcement['id'];
        final deleted = await _deleteNotification(announcementId);
        if (deleted) {
          setState(() {
            announcements.removeWhere((a) => a['id'] == announcementId);
          });
          showThemedSnackbar(
            context,
            'Announcement deleted',
            success: true,
          );
        }
      },
      child: GestureDetector(
        onTap: () => _showAnnouncementDialog(announcement),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: getTypeColor('announcement').withOpacity(0.13),
                child: Icon(
                  getTypeIcon('announcement'),
                  color: getTypeColor('announcement'),
                  size: 24,
                ),
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: getTypeColor('announcement'),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  if (channelName.isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.tag,
                          size: 14,
                          color: AppTheme.primaryColor.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '#$channelName',
                          style: TextStyle(
                            color: AppTheme.primaryColor.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.announcement,
                        size: 14,
                        color: AppTheme.primaryColor.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Announcement',
                        style: TextStyle(
                          color: AppTheme.primaryColor.withOpacity(0.6),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppTheme.primaryColor.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          color: AppTheme.primaryColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }

  void _showAnnouncementDialog(Map<String, dynamic> announcement) {
    final title = announcement['message_content'] ?? 'Announcement';
    final channelName = announcement['channel_name'] ?? '';
    final timeAgo = announcement['time_ago'] ?? '';
    final createdAt = announcement['created_at'] ?? '';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: getTypeColor('announcement').withOpacity(0.13),
                    child: Icon(
                      getTypeIcon('announcement'),
                      color: getTypeColor('announcement'),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Announcement',
                          style: TextStyle(
                            color: getTypeColor('announcement'),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (channelName.isNotEmpty)
                          Text(
                            '#$channelName',
                            style: TextStyle(
                              color: AppTheme.primaryColor.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppTheme.primaryColor.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Posted $timeAgo',
                    style: TextStyle(
                      color: AppTheme.primaryColor.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: getTypeColor('announcement'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllAnnouncements() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.announcement_rounded,
                    color: getTypeColor('announcement'),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'All Announcements',
                    style: TextStyle(
                      color: getTypeColor('announcement'),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.separated(
                  itemCount: announcements.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final announcement = announcements[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showAnnouncementDialog(announcement);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              announcement['message_content'] ?? 'Announcement',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (announcement['channel_name']?.isNotEmpty == true) ...[
                                  Icon(
                                    Icons.tag,
                                    size: 14,
                                    color: AppTheme.primaryColor.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '#${announcement['channel_name']}',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor.withOpacity(0.6),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: AppTheme.primaryColor.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  announcement['time_ago'] ?? '',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification, int index) {
    final type = notification['type'] ?? '';
    final userName = notification['user_name'] ?? '';
    final userAvatar = notification['user_avatar'] ?? '';
    final channelName = notification['channel_name'] ?? '';
    final messageContent = notification['message_content'] ?? '';
    final timeAgo = notification['time_ago'] ?? '';

    // Request (join_request ya request)
    if (type == 'request' || type == 'join_request') {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: getTypeColor(
                      type,
                    ).withOpacity(0.13),
                    backgroundImage:
                        (userAvatar.isNotEmpty &&
                                !userAvatar.contains(
                                  'default-avatar',
                                ))
                            ? NetworkImage(
                                userAvatar.startsWith('http')
                                    ? userAvatar
                                    : ApiConfig.getAssetUrl(userAvatar),
                              )
                            : null,
                    child:
                        (userAvatar.isEmpty ||
                                userAvatar.contains(
                                  'default-avatar',
                                ))
                            ? Icon(
                                getTypeIcon(type),
                                color: getTypeColor(type),
                                size: 24,
                              )
                            : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: userName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: getTypeColor(type),
                                  fontSize: 16,
                                ),
                              ),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text:
                                    'requested to join #$channelName',
                                style: TextStyle(
                                  color:
                                      AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: AppTheme.primaryColor
                                .withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  notifications[index]['_loading'] == true
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Colors.green.shade700,
                            side: BorderSide(
                              color: Colors.green.shade600,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(22),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          onPressed:
                              () => _handleJoinRequestAction(
                                index,
                                true,
                              ),
                          icon: Icon(
                            Icons.check,
                            color: Colors.green.shade600,
                            size: 18,
                          ),
                          label: const Text(
                            'Accept',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                  const SizedBox(width: 8),
                  notifications[index]['_loading'] == true
                      ? const SizedBox(width: 32, height: 32)
                      : OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Colors.red.shade600,
                            side: BorderSide(
                              color: Colors.red.shade400,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(22),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          onPressed:
                              () => _handleJoinRequestAction(
                                index,
                                false,
                              ),
                          icon: Icon(
                            Icons.close,
                            color: Colors.red.shade400,
                            size: 18,
                          ),
                          label: const Text(
                            'Reject',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    // Accepted
    if (type == 'accepted') {
      return Dismissible(
        key: ValueKey(notification.toString() + index.toString()),
        direction: DismissDirection.horizontal,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 28,
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 28,
          ),
        ),
        confirmDismiss:
            (direction) => _confirmDelete(context),
        onDismissed: (direction) async {
          final notifId = notification['id'];
          final deleted = await _deleteNotification(notifId);
          if (deleted) {
            setState(() {
              notifications.removeAt(index);
            });
            showThemedSnackbar(
              context,
              'Notification deleted',
              success: true,
            );
          }
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: getTypeColor(
                  type,
                ).withOpacity(0.13),
                backgroundImage:
                    (userAvatar.isNotEmpty &&
                            !userAvatar.contains(
                              'default-avatar',
                            ))
                        ? NetworkImage(
                            userAvatar.startsWith('http')
                                ? userAvatar
                                : ApiConfig.getAssetUrl(userAvatar),
                          )
                        : null,
                child:
                    (userAvatar.isEmpty ||
                            userAvatar.contains(
                              'default-avatar',
                            ))
                        ? Icon(
                            getTypeIcon(type),
                            color: getTypeColor(type),
                            size: 24,
                          )
                        : null,
              ),
              title: Text(
                'Request Accepted',
                style: TextStyle(
                  color: getTypeColor(type),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Your request to join #$channelName was accepted.',
                style: TextStyle(
                  color: AppTheme.primaryColor.withOpacity(
                    0.85,
                  ),
                  fontSize: 14,
                ),
              ),
              trailing: Text(
                timeAgo,
                style: TextStyle(
                  color: AppTheme.primaryColor.withOpacity(
                    0.6,
                  ),
                  fontSize: 13,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: Colors.transparent,
            ),
          ),
        ),
      );
    }
    // Rejected
    if (type == 'rejected') {
      return Dismissible(
        key: ValueKey(notification.toString() + index.toString()),
        direction: DismissDirection.horizontal,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 28,
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 28,
          ),
        ),
        confirmDismiss:
            (direction) => _confirmDelete(context),
        onDismissed: (direction) async {
          final notifId = notification['id'];
          final deleted = await _deleteNotification(notifId);
          if (deleted) {
            setState(() {
              notifications.removeAt(index);
            });
            showThemedSnackbar(
              context,
              'Notification deleted',
              success: true,
            );
          }
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: getTypeColor(
                  type,
                ).withOpacity(0.13),
                backgroundImage:
                    (userAvatar.isNotEmpty &&
                            !userAvatar.contains(
                              'default-avatar',
                            ))
                        ? NetworkImage(
                            userAvatar.startsWith('http')
                                ? userAvatar
                                : ApiConfig.getAssetUrl(userAvatar),
                          )
                        : null,
                child:
                    (userAvatar.isEmpty ||
                            userAvatar.contains(
                              'default-avatar',
                            ))
                        ? Icon(
                            getTypeIcon(type),
                            color: getTypeColor(type),
                            size: 24,
                          )
                        : null,
              ),
              title: Text(
                'Request Rejected',
                style: TextStyle(
                  color: getTypeColor(type),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Your request to join #$channelName was rejected.',
                style: TextStyle(
                  color: AppTheme.primaryColor.withOpacity(
                    0.85,
                  ),
                  fontSize: 14,
                ),
              ),
              trailing: Text(
                timeAgo,
                style: TextStyle(
                  color: AppTheme.primaryColor.withOpacity(
                    0.6,
                  ),
                  fontSize: 13,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: Colors.transparent,
            ),
          ),
        ),
      );
    }
    // Mention
    if (type == 'mention') {
      return Dismissible(
        key: ValueKey(notification.toString() + index.toString()),
        direction: DismissDirection.horizontal,
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 28,
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 28,
          ),
        ),
        confirmDismiss:
            (direction) => _confirmDelete(context),
        onDismissed: (direction) async {
          final notifId = notification['id'];
          final deleted = await _deleteNotification(notifId);
          if (deleted) {
            setState(() {
              notifications.removeAt(index);
            });
            showThemedSnackbar(
              context,
              'Notification deleted',
              success: true,
            );
          }
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: getTypeColor(
                  type,
                ).withOpacity(0.13),
                backgroundImage:
                    (userAvatar.isNotEmpty &&
                            !userAvatar.contains(
                              'default-avatar',
                            ))
                        ? NetworkImage(
                            userAvatar.startsWith('http')
                                ? userAvatar
                                : ApiConfig.getAssetUrl(userAvatar),
                          )
                        : null,
                child:
                    (userAvatar.isEmpty ||
                            userAvatar.contains(
                              'default-avatar',
                            ))
                        ? Icon(
                            getTypeIcon(type),
                            color: getTypeColor(type),
                            size: 24,
                          )
                        : null,
              ),
              title: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1e5955),
                        fontSize: 16,
                      ),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: 'mentioned you in ',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    TextSpan(
                      text: '#$channelName',
                      style: TextStyle(
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.alternate_email,
                      size: 16,
                      color: AppTheme.secondaryColor.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'You were mentioned in a message',
                        style: TextStyle(
                          color: AppTheme.primaryColor.withOpacity(0.7),
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Text(
                timeAgo,
                style: TextStyle(
                  color: AppTheme.primaryColor.withOpacity(
                    0.6,
                  ),
                  fontSize: 13,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              tileColor: Colors.transparent,
            ),
          ),
        ),
      );
    }
    // Default fallback
    return SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FBFB), Color(0xFFE8F5F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 32),
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off,
                            size: 64,
                            color: AppTheme.primaryColor.withOpacity(0.7),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Oops! Unable to load activity.',
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
                            label: Text('Try Again', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: () {
                              _fetchActivities();
                            },
                          ),
                        ],
                      ),
                    )
                  : (notifications.isEmpty && announcements.isEmpty)
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 60,
                          color: AppTheme.primaryColor.withOpacity(0.18),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No activity yet',
                          style: TextStyle(
                            fontSize: 20,
                            color: AppTheme.primaryColor.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You will see notifications and announcements here',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ],
                    ),
                  )
                  : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Announcements Section
                        if (announcements.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.announcement_rounded,
                                  color: getTypeColor('announcement'),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Announcements',
                                  style: TextStyle(
                                    color: getTypeColor('announcement'),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: getTypeColor('announcement').withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${announcements.length}',
                                    style: TextStyle(
                                      color: getTypeColor('announcement'),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (announcements.length > 3)
                                  TextButton(
                                    onPressed: () => _showAllAnnouncements(),
                                    child: Text(
                                      'See All',
                                      style: TextStyle(
                                        color: getTypeColor('announcement'),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ...announcements.take(3).map((announcement) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildAnnouncementItem(announcement),
                          )).toList(),
                          const SizedBox(height: 20),
                        ],
                        
                        // Notifications Section
                        if (notifications.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.notifications_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Notifications',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${notifications.length}',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...notifications.asMap().entries.map((entry) {
                            final index = entry.key;
                            final notification = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildNotificationItem(notification, index),
                            );
                          }).toList(),
                        ],
                      ],
                    ),
                  ),
        ),
      ),
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

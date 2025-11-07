import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../utils/storage.dart';
import 'package:html/parser.dart' as html_parser;
import '../config/api_config.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Timer? _pollingTimer;
  int _lastNotificationId = 0;

  Future<void> initialize() async {
    // Request permissions first
    await _requestPermissions();

    // Initialize notification settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_notification',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel for Android
    await _createNotificationChannel();
  }

  Future<void> _requestPermissions() async {
    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    final iosPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'chatrox_channel2',
      'Chatrox Notifications',
      description: 'Notifications for Chatrox app',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );

    final androidPlugin =
        _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
    }
  }

  void _onNotificationTap(NotificationResponse response) async {
    // Handle notification tap
    print('Notification tapped: \\${response.payload}');
    if (response.payload != null && response.payload!.contains(':')) {
      final parts = response.payload!.split(':');
      if (parts.length == 2) {
        final notifId = parts[1];
        await _markNotificationAsRead(notifId);
      }
    }
    // TODO: Navigate to appropriate screen based on notification type
  }

  Future<void> _markNotificationAsRead(String notifId) async {
    try {
      final token = await Storage.getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.markAsReadEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'notification_id': notifId}),
      );
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        print('Notification marked as read');
      } else {
        print('Failed to mark as read: \\${data['message']}');
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> startPolling() async {
    _pollingTimer?.cancel();
    // Optimized polling interval - will be replaced with WebSocket when ready
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchNotifications();
    });
  }

  Future<void> stopPolling() async {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _fetchNotifications() async {
    try {
      final token = await Storage.getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.getNotificationsEndpoint),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final notifications = data['data']['notifications'] as List;
          for (var notification in notifications) {
            if (notification['id'] > _lastNotificationId) {
              await _showNotification(notification);
              _lastNotificationId = notification['id'];
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  // Helper function to strip HTML tags from text
  String _stripHtmlTags(String htmlText) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlText.replaceAll(exp, '');
  }

  Future<void> _showNotification(Map<String, dynamic> notification) async {
    final type = notification['type'];
    final user = notification['user'];
    final rawMessage = notification['message'];
    String message = html_parser.parse(rawMessage ?? '').body?.text ?? '';
    final channelName = notification['channel_name'];

    String title;
    String body;
    String? payload;

    switch (type) {
      case 'private_message':
        title = 'New message from \\${user['name']}';
        body = message;
        payload = 'private_message:\\${notification['id']}';
        break;
      case 'channel_message':
        title = 'New message in $channelName';
        body = '\\${user['name']}: $message';
        payload = 'channel_message:\\${notification['id']}';
        break;
      case 'mention':
        title = 'You were mentioned in $channelName';
        body = '\\${user['name']}: $message';
        payload = 'mention:\\${notification['id']}';
        break;
      case 'request':
        title = 'New join request';
        body = '\\${user['name']} wants to join $channelName';
        payload = 'request:\\${notification['id']}';
        break;
      case 'accepted':
        title = 'Request accepted';
        body = 'You can now join $channelName';
        payload = 'accepted:\\${notification['id']}';
        break;
      case 'rejected':
        title = 'Request rejected';
        body = 'Your request to join $channelName was rejected';
        payload = 'rejected:\\${notification['id']}';
        break;
      default:
        title = 'New notification';
        body = message;
        payload = 'default:\\${notification['id']}';
    }

    const androidDetails = AndroidNotificationDetails(
      'chatrox_channel2',
      'Chatrox Notifications',
      channelDescription: 'Notifications for Chatrox app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('notification'),
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_notification'),
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification.mp3',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      notification['id'],
      title,
      body,
      details,
      payload: payload,
    );
  }
} 

import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../widgets/common_app_bar.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> with SingleTickerProviderStateMixin {
  bool channelNotifications = true;
  bool privateMessagesNotifications = true;
  bool activityNotifications = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildSwitchTile({required IconData icon, required String title, required String subtitle, required bool value, required Function(bool) onChanged, Color? iconColor}) {
    String decodedSubtitle = html_parser.parse(subtitle ?? '').text as String;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (iconColor ?? AppTheme.primaryColor).withOpacity(0.09),
          child: Icon(icon, color: iconColor ?? AppTheme.primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(decodedSubtitle, style: const TextStyle(fontSize: 13)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.secondaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.mainGradient,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: CommonAppBar(
            title: 'Notifications',
            backgroundColor: Colors.transparent,
            textColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 66),
              const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1e5955))),
              if (_error != null)
                Center(
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
                        'Oops! Unable to load notification settings.',
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
                          // Add retry logic here, e.g., _fetchNotificationSettings();
                        },
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: [
                    _buildSwitchTile(
                      icon: Icons.forum_outlined,
                      title: 'Channel Notifications',
                      subtitle: 'Show notifications for new channel messages',
                      value: channelNotifications,
                      onChanged: (val) => setState(() => channelNotifications = val),
                      iconColor: AppTheme.secondaryColor,
                    ),
                    _buildSwitchTile(
                      icon: Icons.lock_outline,
                      title: 'Private Messages Notifications',
                      subtitle: 'Show notifications for private messages',
                      value: privateMessagesNotifications,
                      onChanged: (val) => setState(() => privateMessagesNotifications = val),
                      iconColor: AppTheme.primaryColor,
                    ),
                    _buildSwitchTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Activity Notifications',
                      subtitle: 'Show notifications for activity updates',
                      value: activityNotifications,
                      onChanged: (val) => setState(() => activityNotifications = val),
                      iconColor: Colors.orange,
                    ),
                  ],
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 6,
                    shadowColor: AppTheme.secondaryColor.withOpacity(0.3),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification settings saved! (dummy action)')),
                    );
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../config/api_config.dart';
import '../widgets/common_app_bar.dart';
import 'profile_screen.dart';
import 'security_screen.dart';
import 'notification_settings_screen.dart';
import 'theme_appearance_screen.dart';
import 'help_support_screen.dart';
import 'about_screen.dart';
import '../services/user_profile_service.dart';
import '../models/user_profile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserProfile? userProfile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final profile = await UserProfileService.getProfile();
      setState(() {
        userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String getFullImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    String cleanPath = path.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
    return ApiConfig.getAssetUrl(cleanPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FDFD),
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
            title: 'Settings',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
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
                        'Oops! Unable to load settings.',
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
                          _fetchProfile();
                        },
                      ),
                    ],
                  ),
                )
              : ListView(
        padding: const EdgeInsets.fromLTRB(18, 60, 18, 18),
        children: [
           // Profile Info
          Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.13),
                          backgroundImage: userProfile != null && userProfile!.profilePicture.isNotEmpty
                              ? NetworkImage(getFullImageUrl(userProfile!.profilePicture))
                              : null,
                          child: userProfile != null && userProfile!.profilePicture.isEmpty
                              ? Text(
                                  userProfile!.fullName.isNotEmpty ? userProfile!.fullName[0] : '',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 38,
                                  ),
                                )
                              : null,
              ),
              const SizedBox(height: 16),
                        Text(
                          userProfile?.fullName ?? '',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.grey[800]),
                        ),
              const SizedBox(height: 4),
                        Text(
                          userProfile?.email ?? '',
                          style: TextStyle(color: Colors.grey[600], fontSize: 15),
                        ),
              const SizedBox(height: 18),
            ],
          ),
          // Account Settings Section
          const SizedBox(height: 10),
          Text('Account Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                _settingsTile(
                  context,
                  icon: Icons.security,
                  title: 'Security',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SecurityScreen()));
                  },
                ),
                _divider(),
                _settingsTile(
                  context,
                  icon: Icons.notifications_none,
                  title: 'Notifications',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationSettingsScreen()));
                  },
                ),
              ],
            ),
          ),
          // App Settings Section
          const SizedBox(height: 22),
          Text('App Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: _settingsTile(
              context,
              icon: Icons.brightness_2_outlined,
              title: 'Theme Mode',
              trailing: Text('Light', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ThemeAppearanceScreen()));
              },
            ),
          ),
          // Support Section
          const SizedBox(height: 22),
          Text('Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                _settingsTile(
                  context,
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpSupportScreen()));
                  },
                ),
                _divider(),
                _settingsTile(
                  context,
                  icon: Icons.info_outline,
                  title: 'About App',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen()));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Divider(height: 0, thickness: 1, color: Colors.grey[200]);

  Widget _settingsTile(BuildContext context, {required IconData icon, required String title, Widget? trailing, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: AppTheme.primaryColor, size: 26),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
      onTap: onTap,
    );
  }
} 
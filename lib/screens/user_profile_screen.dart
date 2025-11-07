import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/theme.dart';
import '../config/api_config.dart';
import '../widgets/common_app_bar.dart';
import '../screens/all_media_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  const UserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? user;
  List<dynamic> media = [];
  List<dynamic> commonGroups = [];

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }
      final url = Uri.parse(ApiConfig.getUserDetailsEndpoint);
      final response = await http.post(
        url,
        body: json.encode({'user_id': widget.userId}),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        setState(() {
          user = data['data']['user'];
          media = data['data']['media'] ?? [];
          commonGroups = data['data']['common_channels'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() { _error = data['message'] ?? 'Failed to load user'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
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
          ),
          child: CommonAppBar(
            title: 'Contact Info',
            backgroundColor: Colors.transparent,
            textColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : user == null
                  ? const Center(child: Text('No user data'))
                  : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 100, 0, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar & Name
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.13),
                                  backgroundImage: user!["profile_picture"] != null && user!["profile_picture"].toString().isNotEmpty
                                      ? NetworkImage(getFullImageUrl(user!["profile_picture"]))
                                      : null,
                                  child: (user!["profile_picture"] == null || user!["profile_picture"].toString().isEmpty)
                                      ? Text(user!["full_name"] != null && user!["full_name"].toString().isNotEmpty ? user!["full_name"][0] : '', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 32))
                        : null,
                  ),
                  const SizedBox(height: 14),
                                Text(user!["full_name"] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.primaryColor)),
                  const SizedBox(height: 6),
                                if (user!["username"] != null && user!["username"].toString().isNotEmpty)
                                  Text('@${user!["username"]}', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                  const SizedBox(height: 10),
                 
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Media Preview
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Text('Media', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.arrow_forward_ios, color: AppTheme.secondaryColor, size: 20),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                                        builder: (context) => AllMediaScreen(
                                          mediaList: media.map((m) => {
                                            'url': getFullImageUrl(m['file_path']),
                                            'sender': user!["full_name"] ?? '',
                                          }.map((k, v) => MapEntry(k, v?.toString() ?? ''))).cast<Map<String, String>>().toList(),
                                        ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 80,
                            child: media.isEmpty
                                ? const Center(child: Text('No media', style: TextStyle(color: Colors.grey)))
                                : ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                                    itemCount: media.length > 5 ? 5 : media.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                                      final m = media[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                                          getFullImageUrl(m['file_path']),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            // Number & About
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Contact Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87, letterSpacing: 0.2)),
                  const SizedBox(height: 10),
                  if (user!["phone"] != null && user!["phone"].toString().isNotEmpty)
                    _ProfileCardItem(
                      icon: Icons.phone_outlined,
                      title: 'Phone',
                      value: user!["phone"],
                    ),
                  if (user!["email"] != null && user!["email"].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: _ProfileCardItem(
                        icon: Icons.email_outlined,
                        title: 'Email',
                        value: user!["email"],
                      ),
                    ),
                  if (user!["bio"] != null && user!["bio"].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: _ProfileCardItem(
                        icon: Icons.info_outline,
                        title: 'About',
                        value: user!["bio"],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Common Groups
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Common Groups', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                  const SizedBox(height: 10),
                  if (commonGroups.isEmpty)
                    const Text('No common groups', style: TextStyle(color: Colors.grey)),
                  if (commonGroups.isNotEmpty)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: commonGroups.map<Widget>((group) => Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        elevation: 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {},
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.13),
                              child: Icon(Icons.group, color: AppTheme.primaryColor, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(group['name'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCardItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _ProfileCardItem({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: valueColor ?? Colors.black54,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Icon(Icons.edit_outlined, color: AppTheme.secondaryColor.withOpacity(0.8), size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 
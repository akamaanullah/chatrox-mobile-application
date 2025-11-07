import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'edit_name_screen.dart';
import 'edit_about_screen.dart';
import 'edit_links_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/user_profile_service.dart';
import '../models/user_profile.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'channel_chat_screen.dart';
import '../config/api_config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;
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

  Future<void> _handleLogout() async {
    setState(() {
      _isLoggingOut = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final sessionId = prefs.getString('session_id');
    try {
      final url = Uri.parse(ApiConfig.logoutEndpoint);
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'session_id': sessionId,
        }),
      );
      print('Logout response: ${response.body}');
    } catch (e) {
      print('Logout error: $e');
    }
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
    setState(() {
      _isLoggingOut = false;
    });
  }

  String getFullImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    String cleanPath = path.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
    return ApiConfig.getAssetUrl(cleanPath);
  }

  Future<void> _showProfilePicOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (userProfile?.profilePicture != null && userProfile!.profilePicture.isNotEmpty)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.visibility, color: AppTheme.primaryColor),
                  ),
                  title: const Text('View Profile Picture'),
                  subtitle: const Text('Full size view'),
                  onTap: () {
                    Navigator.pop(context);
                    _showProfilePictureViewer();
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.photo_camera, color: AppTheme.primaryColor),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.photo_library, color: AppTheme.primaryColor),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select from photos'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.gallery);
                },
              ),
              if (userProfile?.profilePicture != null && userProfile!.profilePicture.isNotEmpty)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.delete_forever, color: Colors.red),
                  ),
                  title: const Text('Remove Profile Picture', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Delete current picture'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _showRemoveConfirmation();
                  },
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
      
      if (picked != null) {
        await _updateProfilePicture(picked);
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  Future<void> _updateProfilePicture(XFile picked) async {
    setState(() { _isLoading = true; });
    
    try {
      final token = await SharedPreferences.getInstance().then((prefs) => prefs.getString('token'));
      if (token == null) {
        throw Exception('No authentication token found');
      }

      print('DEBUG: Starting profile picture update...');
      print('DEBUG: Token: ${token.substring(0, 20)}...');
      print('DEBUG: Image path: ${picked.path}');
      print('DEBUG: Image size: ${await File(picked.path).length()} bytes');

              final url = Uri.parse(ApiConfig.updateProfileEndpoint);
      var request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      
      // Add the image file
      request.files.add(await http.MultipartFile.fromPath('profile_picture', picked.path));
      
      print('DEBUG: Request URL: $url');
      print('DEBUG: Request headers: ${request.headers}');
      print('DEBUG: Request fields: ${request.fields}');
      print('DEBUG: Request files: ${request.files.map((f) => '${f.field}: ${f.filename}').toList()}');
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response headers: ${response.headers}');
      print('DEBUG: Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          await _fetchProfile();
          _showSuccessSnackBar('Profile picture updated successfully!');
        } else {
          _showErrorSnackBar(data['message'] ?? 'Failed to update profile picture');
        }
      } else {
        print('DEBUG: HTTP Error ${response.statusCode}: ${response.body}');
        _showErrorSnackBar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Exception in update profile picture: $e');
      print('DEBUG: Exception stack trace: ${StackTrace.current}');
      _showErrorSnackBar('Error updating profile picture: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _showRemoveConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Profile Picture'),
        content: const Text('Are you sure you want to remove your profile picture? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeProfilePicture();
    }
  }

  Future<void> _removeProfilePicture() async {
    setState(() { _isLoading = true; });
    
    try {
      final token = await SharedPreferences.getInstance().then((prefs) => prefs.getString('token'));
      if (token == null) {
        throw Exception('No authentication token found');
      }

      print('DEBUG: Starting profile picture removal...');
      print('DEBUG: Token: ${token.substring(0, 20)}...');

              final url = Uri.parse(ApiConfig.removeProfileEndpoint);
      
      print('DEBUG: Request URL: $url');
      print('DEBUG: Request method: DELETE');
      
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      
      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response headers: ${response.headers}');
      print('DEBUG: Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          await _fetchProfile();
          _showSuccessSnackBar('Profile picture removed successfully!');
        } else {
          _showErrorSnackBar(data['message'] ?? 'Failed to remove profile picture');
        }
      } else {
        print('DEBUG: HTTP Error ${response.statusCode}: ${response.body}');
        _showErrorSnackBar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('DEBUG: Exception in remove profile picture: $e');
      print('DEBUG: Exception stack trace: ${StackTrace.current}');
      _showErrorSnackBar('Error removing profile picture: $e');
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  void _showProfilePictureViewer() {
    if (userProfile?.profilePicture == null || userProfile!.profilePicture.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    getFullImageUrl(userProfile!.profilePicture),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FBFB), Color(0xFFE8F5F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
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
                          'Oops! Unable to load profile.',
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
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Try Again', style: TextStyle(color: Colors.white)),
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
                : userProfile == null
                    ? const Center(child: Text('No profile data'))
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 32, 18, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Profile Picture Section
                              Center(
                                child: GestureDetector(
                                  onTap: _showProfilePicOptions,
                                  child: Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primaryColor.withOpacity(0.18),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: CircleAvatar(
                                          radius: 66,
                                          backgroundColor: Colors.white,
                                          backgroundImage: userProfile!.profilePicture.isNotEmpty
                                              ? NetworkImage(getFullImageUrl(userProfile!.profilePicture))
                                              : null,
                                          child: userProfile!.profilePicture.isEmpty
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
                                      ),
                                      // Edit Icon
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primaryColor.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Profile Picture Options Text
                              GestureDetector(
                                onTap: _showProfilePicOptions,
                                child: Text(
                                  'Tap to change profile picture',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Profile Information Cards
                              _ProfileCardItem(
                                icon: Icons.person_outline,
                                title: 'Name',
                                value: userProfile!.fullName,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditNameScreen(initialName: userProfile!.fullName),
                                    ),
                                  ).then((_) => _fetchProfile());
                                },
                              ),
                              const SizedBox(height: 16),
                              _ProfileCardItem(
                                icon: Icons.info_outline,
                                title: 'About',
                                value: userProfile!.about.isNotEmpty ? userProfile!.about : 'No about info',
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditAboutScreen(currentAbout: userProfile!.about),
                                    ),
                                  );
                                  if (result != null) {
                                    setState(() {
                                      userProfile = userProfile!.copyWith(about: result);
                                    });
                                    await _fetchProfile();
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              _ProfileCardItem(
                                icon: Icons.phone_outlined,
                                title: 'Phone',
                                value: userProfile!.phone,
                              ),
                              const SizedBox(height: 16),
                              _ProfileCardItem(
                                icon: Icons.email_outlined,
                                title: 'Email',
                                value: userProfile!.email,
                              ),
                              const SizedBox(height: 16),
                              _ProfileCardItem(
                                icon: Icons.business_outlined,
                                title: 'Company',
                                value: userProfile!.companyName,
                              ),
                              const SizedBox(height: 24),
                              // Channels Section
                              if (userProfile!.channels.isNotEmpty)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 18),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.08),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.08)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.tag, color: Colors.deepPurple, size: 22),
                                          SizedBox(width: 8),
                                          Text('Channels', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: userProfile!.channels.map((c) => InkWell(
                                          borderRadius: BorderRadius.circular(10),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChannelChatScreen(
                                                  channelName: c.name,
                                                  channelDescription: '',
                                                  channelAvatar: '',
                                                  channelId: c.id,
                                                  isPrivate: false,
                                                  membersCount: 0,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Chip(
                                            label: Text(c.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                            backgroundColor: AppTheme.primaryColor.withOpacity(0.09),
                                            avatar: const Icon(Icons.tag, size: 18, color: Colors.deepPurple),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        )).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              // Logout Button
                              Container(
                                width: double.infinity,
                                height: 55,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(0.18),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoggingOut ? null : _handleLogout,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _isLoggingOut
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(Icons.logout, color: Colors.white, size: 24),
                                            SizedBox(width: 8),
                                            Text(
                                              'Logout',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
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
                child: Icon(icon, color: AppTheme.primaryColor, size: 26),
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
                        fontSize: 16,
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
                    child: Icon(Icons.edit_outlined, color: AppTheme.secondaryColor.withOpacity(0.8), size: 22),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../config/api_config.dart';
import '../models/channel_detail.dart';
import '../services/channel_detail_service.dart';
import '../utils/storage.dart';
import 'package:intl/intl.dart';
import 'all_media_screen.dart';
import 'package:http/http.dart' as http;
import '../models/contact.dart';
import '../services/contact_service.dart';
import 'dart:convert';
import '../models/channel_member.dart';
import 'channel_chat_screen.dart';
import '../services/channel_service.dart';

class ChannelProfileScreen extends StatefulWidget {
  final int channelId;
  const ChannelProfileScreen({Key? key, required this.channelId}) : super(key: key);

  @override
  State<ChannelProfileScreen> createState() => _ChannelProfileScreenState();
}

class _ChannelProfileScreenState extends State<ChannelProfileScreen> {
  ChannelDetail? channelDetail;
  bool _isLoading = true;
  String? _error;
  int? _currentUserId;
  static const String kBaseUrl = 'http://172.16.32.59:8886/';

  // Selection mode state
  Set<int> selectedMemberIds = {};
  bool get isSelectionMode => isCurrentUserAdmin && selectedMemberIds.isNotEmpty;

  Set<int> selectedContactIds = {};
  List<Contact>? allContacts;
  bool _isLoadingContacts = false;

  String getFullImageUrl(String? path) {
    if (path == null || path.trim().isEmpty) return '';
    if (path.startsWith('http') || path.startsWith('https')) return path;
    String cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return ApiConfig.getAssetUrl(cleanPath);
  }

  bool get isCurrentUserAdmin {
    if (channelDetail == null || _currentUserId == null) return false;
    return channelDetail!.members.any((m) => m.id == _currentUserId && m.role == 'admin');
  }
  bool get isCurrentUserMember {
    if (channelDetail == null || _currentUserId == null) return false;
    return channelDetail!.members.any((m) => m.id == _currentUserId && (m.role == 'member' || m.role == 'admin'));
  }

  String getReadableDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('d MMM, yyyy').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final userId = await Storage.getUserId();
    setState(() { _currentUserId = userId; });
    await _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final detail = await ChannelDetailService.getChannelDetail(widget.channelId);
      setState(() {
        channelDetail = detail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      setState(() => selectedMemberIds.clear());
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
            title: isSelectionMode
                ? Text('${selectedMemberIds.length} selected', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                : const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('Channel Info', style: TextStyle(color: Colors.white)),
                  ),
            centerTitle: false,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : channelDetail == null
                  ? const Center(child: Text('No data found'))
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(0, 32, 0, 8),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Avatar & Name
                            Center(
                              child: Column(
                                children: [
                                  const SizedBox(height: 70), // Top margin for avatar and info
                                  CircleAvatar(
                                    radius: 48,
                                    backgroundColor: AppTheme.primaryColor.withOpacity(0.13),
                                    backgroundImage: null,
                                    child: Center(
                                      child: Text(
                                        '#',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 48,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(channelDetail!.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.primaryColor)),
                                  const SizedBox(height: 6),
                                  Container(
                                    alignment: Alignment.center,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: channelDetail!.isPrivate ? AppTheme.primaryColor.withOpacity(0.18) : AppTheme.secondaryColor.withOpacity(0.18),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            channelDetail!.isPrivate ? 'Private' : 'Public',
                                            style: TextStyle(
                                              color: AppTheme.primaryColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Created: ${getReadableDate(channelDetail!.createdAt)}',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'by ${channelDetail!.creator.name}',
                                          style: TextStyle(
                                            color: AppTheme.secondaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  // Buttons logic
                                  if (isCurrentUserAdmin)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.secondaryColor,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                          ),
                                          onPressed: _showEditChannelModal,
                                          icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                          label: const Text('Edit Channel', style: TextStyle(color: Colors.white)),
                                        ),
                                        const SizedBox(width: 12),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primaryColor,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChannelChatScreen(
                                                  channelName: channelDetail!.name,
                                                  channelDescription: channelDetail!.description,
                                                  channelAvatar: '',
                                                  channelId: channelDetail!.id,
                                                  isPrivate: channelDetail!.isPrivate,
                                                  membersCount: channelDetail!.memberCount,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.message, color: Colors.white, size: 20),
                                          label: const Text('Message', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    )
                                  else if (isCurrentUserMember)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChannelChatScreen(
                                              channelName: channelDetail!.name,
                                              channelDescription: channelDetail!.description,
                                              channelAvatar: '',
                                              channelId: channelDetail!.id,
                                              isPrivate: channelDetail!.isPrivate,
                                              membersCount: channelDetail!.memberCount,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.message, color: Colors.white, size: 20),
                                      label: const Text('Message', style: TextStyle(color: Colors.white)),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            // About Section (moved up)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            'About Channel',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: AppTheme.primaryColor,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      channelDetail!.description.isEmpty
                                          ? const Text('No about info', style: TextStyle(color: Colors.grey))
                                          : Text(channelDetail!.description, style: const TextStyle(fontSize: 15)),
                                    ],
                                  ),
                                ),
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
                                      final mediaList = channelDetail!.media.map((m) => {
                                        'url': getFullImageUrl(m.filePath),
                                        'sender': m.uploadedByName,
                                      }).toList();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AllMediaScreen(mediaList: mediaList),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            channelDetail!.media.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text('No media', style: TextStyle(color: Colors.grey)),
                                  )
                                : SizedBox(
                                    height: 80,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 18),
                                      itemCount: channelDetail!.media.length > 5 ? 5 : channelDetail!.media.length,
                                      separatorBuilder: (context, index) => const SizedBox(width: 10),
                                      itemBuilder: (context, index) {
                                        final media = channelDetail!.media[index];
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            getFullImageUrl(media.filePath),
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
                            // Members List
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: Row(
                                children: [
                                  const Text('Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                  const Spacer(),
                                  if (isCurrentUserAdmin)
                                    IconButton(
                                      icon: Icon(Icons.person_add, color: AppTheme.secondaryColor, size: 22),
                                      onPressed: _showAddMembersModal,
                                    ),
                                ],
                              ),
                            ),
                            channelDetail!.members.isEmpty
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text('No members', style: TextStyle(color: Colors.grey)),
                                  )
                                : ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 18),
                                    itemCount: channelDetail!.members.length,
                                    separatorBuilder: (context, i) => const Divider(height: 1),
                                    itemBuilder: (context, i) {
                                      final m = channelDetail!.members[i];
                                      final isAdmin = m.role == 'admin';
                                      final isSelected = selectedMemberIds.contains(m.id);
                                      final isDisabled = isSelectionMode && isAdmin;
                                      return GestureDetector(
                                        onLongPress: isCurrentUserAdmin && !isAdmin
                                            ? () {
                                                if (!isSelectionMode) {
                                                  setState(() {
                                                    selectedMemberIds.add(m.id);
                                                  });
                                                }
                                              }
                                            : null,
                                        onTap: isSelectionMode && !isAdmin
                                            ? () {
                                                setState(() {
                                                  if (isSelected) {
                                                    selectedMemberIds.remove(m.id);
                                                  } else {
                                                    selectedMemberIds.add(m.id);
                                                  }
                                                });
                                              }
                                            : null,
                                        child: Opacity(
                                          opacity: isDisabled ? 0.5 : 1.0,
                                          child: Container(
                                            color: isSelected ? AppTheme.primaryColor.withOpacity(0.08) : null,
                                            child: ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor: AppTheme.primaryColor.withOpacity(0.13),
                                                backgroundImage: (m.profilePicture != null && m.profilePicture.trim().isNotEmpty)
                                                    ? NetworkImage(getFullImageUrl(m.profilePicture))
                                                    : null,
                                                child: (m.profilePicture == null || m.profilePicture.trim().isEmpty)
                                                    ? Center(
                                                        child: Text(
                                                          m.fullName.isNotEmpty ? m.fullName[0].toUpperCase() : '',
                                                          style: TextStyle(
                                                            color: AppTheme.primaryColor,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 20,
                                                          ),
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              title: Text(m.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              subtitle: Text(m.role, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                              trailing: isSelectionMode
                                                  ? isSelected
                                                      ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
                                                      : null
                                                  : null,
                                              enabled: !isDisabled,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                            const SizedBox(height: 24),
                            // Leave/Delete Channel (bottom)
                            if (isCurrentUserAdmin) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _isLoading ? null : () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Delete Channel'),
                                              content: const Text('Are you sure you want to delete this channel? This action cannot be undone.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm != true) return;
                                          setState(() { _isLoading = true; });
                                          try {
                                            final success = await ChannelService.deleteChannel(channelDetail!.id);
                                            if (success) {
                                              if (mounted) {
                                                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                                                showThemedSnackbar(context, 'Channel deleted successfully.', success: true);
                                              }
                                            }
                                          } catch (e) {
                                            showThemedSnackbar(context, 'Error: $e', success: false);
                                          } finally {
                                            if (mounted) setState(() { _isLoading = false; });
                                          }
                                        },
                                        icon: const Icon(Icons.delete, color: Colors.white),
                                        label: const Text('Delete Channel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.error,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          elevation: 0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _isLoading ? null : () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Leave Channel'),
                                              content: const Text('Are you sure you want to leave this channel?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                  child: const Text('Leave', style: TextStyle(color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm != true) return;
                                          setState(() { _isLoading = true; });
                                          try {
                                            final success = await ChannelService.leaveChannel(channelDetail!.id);
                                            if (success) {
                                              if (mounted) {
                                                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                                                showThemedSnackbar(context, 'Successfully left the channel', success: true);
                                              }
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Row(
                                                    children: [
                                                      const Icon(Icons.error_outline, color: Colors.white),
                                                      const SizedBox(width: 12),
                                                      Expanded(child: Text('Error: $e', style: const TextStyle(fontSize: 15))),
                                                    ],
                                                  ),
                                                  backgroundColor: Colors.red,
                                                  behavior: SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  margin: const EdgeInsets.all(10),
                                                  duration: const Duration(seconds: 3),
                                                ),
                                              );
                                            }
                                          } finally {
                                            if (mounted) setState(() { _isLoading = false; });
                                          }
                                        },
                                        icon: Icon(Icons.exit_to_app, color: Theme.of(context).colorScheme.error),
                                        label: const Text('Leave Channel', style: TextStyle(fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoading ? null : () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Leave Channel'),
                                          content: const Text('Are you sure you want to leave this channel?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              child: const Text('Leave', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm != true) return;
                                      setState(() { _isLoading = true; });
                                      try {
                                        final success = await ChannelService.leaveChannel(channelDetail!.id);
                                        if (success) {
                                          if (mounted) {
                                            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
                                            showThemedSnackbar(context, 'Successfully left the channel', success: true);
                                          }
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.error_outline, color: Colors.white),
                                                  const SizedBox(width: 12),
                                                  Expanded(child: Text('Error: $e', style: const TextStyle(fontSize: 15))),
                                                ],
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              margin: const EdgeInsets.all(10),
                                              duration: const Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) setState(() { _isLoading = false; });
                                      }
                                    },
                                    icon: Icon(Icons.exit_to_app, color: Theme.of(context).colorScheme.error),
                                    label: const Text('Leave Channel', style: TextStyle(fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Theme.of(context).colorScheme.error, width: 2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: isCurrentUserAdmin && isSelectionMode && selectedMemberIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _removeSelectedMembers,
              icon: const Icon(Icons.person_remove, color: Colors.white),
              label: Text('Remove (${selectedMemberIds.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Theme.of(context).colorScheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              elevation: 2,
            )
          : null,
    );
  }

  Future<void> _removeSelectedMembers() async {
    if (selectedMemberIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Members'),
        content: Text('Are you sure you want to remove ${selectedMemberIds.length} selected member(s) from the channel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() { _isLoading = true; });
    try {
      final token = await Storage.getToken();
              final url = Uri.parse(ApiConfig.removeMembersEndpoint);
      final body = '{"channel_id": ${widget.channelId}, "member_ids": ${selectedMemberIds.toList()}}';
      print('DEBUG: Removing members, channel_id: ${widget.channelId}, member_ids: ${selectedMemberIds.toList()}');
      print('DEBUG: POST $url');
      print('DEBUG: Body: $body');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );
      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response body: ${response.body}');
      if (response.statusCode == 200 && response.body.contains('"status":"success"')) {
        setState(() {
          channelDetail!.members.removeWhere((m) => selectedMemberIds.contains(m.id));
          selectedMemberIds.clear();
          _isLoading = false;
        });
        showThemedSnackbar(context, 'Members removed successfully!', success: true);
      } else {
        setState(() { _isLoading = false; });
        showThemedSnackbar(context, 'Failed to remove members.', success: false);
      }
    } catch (e, st) {
      print('DEBUG: Exception: $e\n$st');
      setState(() { _isLoading = false; });
      showThemedSnackbar(context, 'Error: $e', success: false);
    }
  }

  Future<void> _showAddMembersModal() async {
    if (allContacts == null) {
      setState(() => _isLoadingContacts = true);
      try {
        allContacts = await ContactService.getAllContacts();
      } catch (e) {
        showThemedSnackbar(context, 'Failed to load contacts: $e', success: false);
        return;
      } finally {
        setState(() => _isLoadingContacts = false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Add Members',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (selectedContactIds.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setModalState(() => selectedContactIds.clear()),
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingContacts
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: allContacts!.length,
                        itemBuilder: (context, index) {
                          final contact = allContacts![index];
                          final isAlreadyMember = channelDetail!.members.any((m) => m.id == contact.id);
                          final isSelected = selectedContactIds.contains(contact.id);

                          return ListTile(
                            enabled: !isAlreadyMember,
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                              backgroundImage: contact.profilePicture != null
                                  ? NetworkImage(getFullImageUrl(contact.profilePicture))
                                  : null,
                              child: contact.profilePicture == null
                                  ? Text(
                                      '${contact.firstName} ${contact.lastName}'[0].toUpperCase(),
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              '${contact.firstName} ${contact.lastName}',
                              style: TextStyle(
                                color: isAlreadyMember ? Colors.grey : null,
                              ),
                            ),
                            subtitle: isAlreadyMember
                                ? const Text('Already a member', style: TextStyle(color: Colors.grey))
                                : null,
                            trailing: isAlreadyMember
                                ? const Icon(Icons.check_circle, color: Colors.grey)
                                : Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setModalState(() {
                                        if (value == true) {
                                          selectedContactIds.add(contact.id);
                                        } else {
                                          selectedContactIds.remove(contact.id);
                                        }
                                      });
                                    },
                                  ),
                          );
                        },
                      ),
              ),
              if (selectedContactIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _addSelectedMembers(),
                      icon: const Icon(Icons.person_add, size: 22),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          'Add ${selectedContactIds.length} Member${selectedContactIds.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 2,
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

  Future<void> _addSelectedMembers() async {
    if (selectedContactIds.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final token = await Storage.getToken();
              final url = Uri.parse(ApiConfig.addMembersEndpoint);
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'channel_id': widget.channelId,
          'member_ids': selectedContactIds.toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          // Update local members list
          final addedMembers = (data['data']['added_members'] as List)
              .map((m) => ChannelDetailMember.fromJson(m))
              .toList();

          setState(() {
            channelDetail!.members.addAll(addedMembers);
            selectedContactIds.clear();
          });

          Navigator.pop(context); // Close modal
          showThemedSnackbar(
            context,
            'Successfully added ${data['data']['added_count']} member(s)',
            success: true,
          );
        } else {
          showThemedSnackbar(context, data['message'] ?? 'Failed to add members', success: false);
        }
      } else {
        showThemedSnackbar(context, 'Failed to add members', success: false);
      }
    } catch (e) {
      showThemedSnackbar(context, 'Error: $e', success: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditChannelModal() async {
    final nameController = TextEditingController(text: channelDetail?.name ?? '');
    final descController = TextEditingController(text: channelDetail?.description ?? '');
    bool isSaving = false;
    bool isPrivate = channelDetail?.isPrivate ?? false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Edit Channel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Channel Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Privacy:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('Public'),
                      selected: !isPrivate,
                      selectedColor: Theme.of(context).secondaryHeaderColor.withOpacity(0.15),
                      onSelected: (v) => setModalState(() => isPrivate = false),
                      labelStyle: TextStyle(color: !isPrivate ? Theme.of(context).secondaryHeaderColor : Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Private'),
                      selected: isPrivate,
                      selectedColor: Theme.of(context).primaryColor.withOpacity(0.15),
                      onSelected: (v) => setModalState(() => isPrivate = true),
                      labelStyle: TextStyle(color: isPrivate ? Theme.of(context).primaryColor : Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setModalState(() => isSaving = true);
                            await _editChannel(nameController.text.trim(), descController.text.trim(), isPrivate);
                            setModalState(() => isSaving = false);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _editChannel(String name, String description, bool isPrivate) async {
    setState(() => _isLoading = true);
    try {
      final token = await Storage.getToken();
              final url = Uri.parse(ApiConfig.editChannelEndpoint);
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'channel_id': widget.channelId,
          'name': name,
          'description': description,
          'is_private': isPrivate,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        bool isSuccess = data['status'] == 'success';
        Navigator.pop(context); // Modal close karo chahe success ho ya error
        if (isSuccess) {
          setState(() {
            channelDetail = channelDetail!.copyWith(
              name: data['data']['name'],
              description: data['data']['description'],
              isPrivate: data['data']['is_private'] == true || data['data']['is_private'] == 1,
              creator: ChannelCreator(
                id: data['data']['created_by'],
                name: data['data']['creator_name'],
                avatar: data['data']['creator_profile_picture'],
              ),
            );
          });
          showThemedSnackbar(context, 'Channel updated successfully', success: true);
          return true;
        } else {
          showThemedSnackbar(context, data['message'] ?? 'Failed to update channel', success: false);
        }
      } else {
        Navigator.pop(context); // Modal close karo agar API error ho
        showThemedSnackbar(context, 'Failed to update channel', success: false);
      }
    } catch (e) {
      showThemedSnackbar(context, 'Error: $e', success: false);
    } finally {
      setState(() => _isLoading = false);
    }
    return false;
  }

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
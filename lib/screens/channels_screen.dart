import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../config/api_config.dart';
import 'channel_chat_screen.dart';
import '../models/channel.dart';
import '../services/channel_service.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({Key? key}) : super(key: key);

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<Channel> channels = [];
  String search = '';
  bool _isLoading = true;
  String? _error;
  int? _joiningChannelId;

  @override
  void initState() {
    super.initState();
    _fetchChannels();
  }

  Future<void> _fetchChannels() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await ChannelService.getChannels();
      setState(() {
        channels = data;
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
    final filteredChannels = channels.where((c) => c.name.toLowerCase().contains(search.toLowerCase())).toList();
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
                  decoration: InputDecoration(
                    hintText: 'Search channels',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (val) => setState(() => search = val),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchChannels,
                child: _isLoading
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
                                  'Oops! Unable to load channels.',
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
                                    _fetchChannels();
                                  },
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: filteredChannels.length,
                separatorBuilder: (context, i) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final channel = filteredChannels[i];
                              final isMember = channel.userRole.isNotEmpty && channel.userRole != 'none';
                              final hasRequested = channel.joinRequests.any((r) => r.status == 'pending');
                              final showMembers = channel.members.take(5).toList();
                              final remaining = channel.memberCount - showMembers.length;
                              print('Channel: \\${channel.name}, members: \\${channel.members.length}, memberCount: \\${channel.memberCount}');
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
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.08)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                            channel.name,
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                                          if (channel.isPrivate)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Private', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.secondaryColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Public', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                                        channel.description,
                            style: const TextStyle(color: Colors.black54, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                            '${channel.memberCount} members',
                                style: const TextStyle(color: Colors.black87, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              Stack(
                                children: [
                                  Row(
                                    children: [
                                      ...List.generate(
                                                    showMembers.length,
                                        (j) => Transform.translate(
                                          offset: Offset(j * -10.0, 0),
                                          child: CircleAvatar(
                                            radius: 13,
                                            backgroundColor: AppTheme.secondaryColor.withOpacity(0.15),
                                            child: Text(
                                                          showMembers[j].firstName.isNotEmpty ? showMembers[j].firstName[0] : '',
                                              style: TextStyle(
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                                  if (remaining > 0)
                                        Transform.translate(
                                                      offset: Offset((showMembers.length) * -10.0, 0),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.secondaryColor.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                                          '+$remaining more',
                                              style: TextStyle(
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                                          if (isMember)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.secondaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  ),
                                  onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChannelChatScreen(
                                                      channelName: channel.name,
                                                      channelDescription: channel.description,
                                                      channelAvatar: '',
                                                      channelId: channel.id,
                                                      isPrivate: channel.isPrivate,
                                                      membersCount: channel.memberCount,
                                                    ),
                                                  ),
                                                );
                                  },
                                  icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white),
                                  label: const Text('Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                )
                                          else if (channel.isPrivate && !hasRequested)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  ),
                                              onPressed: _joiningChannelId == channel.id
                                                  ? null
                                                  : () async {
                                                      setState(() { _joiningChannelId = channel.id; });
                                                      try {
                                                        await ChannelService.requestJoin(channel.id);
                                                        // Local state update: pending request add karo
                                                        setState(() {
                                                          final idx = channels.indexWhere((c) => c.id == channel.id);
                                                          if (idx != -1) {
                                                            channels[idx] = Channel(
                                                              id: channel.id,
                                                              name: channel.name,
                                                              description: channel.description,
                                                              isPrivate: channel.isPrivate,
                                                              createdAt: channel.createdAt,
                                                              updatedAt: channel.updatedAt,
                                                              createdByName: channel.createdByName,
                                                              createdByAvatar: channel.createdByAvatar,
                                                              members: channel.members,
                                                              joinRequests: [
                                                                ...channel.joinRequests,
                                                                ChannelJoinRequest(
                                                                  id: 0,
                                                                  firstName: '',
                                                                  lastName: '',
                                                                  profilePicture: '',
                                                                  status: 'pending',
                                                                  requestedAt: DateTime.now().toIso8601String(),
                                                                ),
                                                              ],
                                                              memberCount: channel.memberCount,
                                                              userRole: channel.userRole,
                                                            );
                                                          }
                                                        });
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Row(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Icon(Icons.check_circle, color: Colors.white, size: 22),
                                                                SizedBox(width: 10),
                                                                Text(
                                                                  'Join request sent!',
                                                                  style: TextStyle(
                                                                    color: Colors.white,
                                                                    fontWeight: FontWeight.bold,
                                                                    fontSize: 16,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            backgroundColor: AppTheme.primaryColor,
                                                            behavior: SnackBarBehavior.floating,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(16),
                                                            ),
                                                            duration: Duration(seconds: 2),
                                                            margin: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                                                          ),
                                                        );
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text(e.toString())),
                                                        );
                                                      } finally {
                                                        setState(() { _joiningChannelId = null; });
                                                      }
                                                    },
                                              icon: _joiningChannelId == channel.id
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                    )
                                                  : const Icon(Icons.lock_outline, size: 18, color: Colors.white),
                                              label: Text(
                                                (_joiningChannelId == channel.id)
                                                    ? 'Requesting...'
                                                    : hasRequested
                                                        ? 'Requested'
                                                        : 'Join Request',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                            )
                                          else if (!channel.isPrivate && !isMember)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.secondaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  ),
                                              onPressed: _joiningChannelId == channel.id
                                                  ? null
                                                  : () async {
                                                      setState(() { _joiningChannelId = channel.id; });
                                                      try {
                                                        await ChannelService.joinPublic(channel.id);
                                                        // Local state update: userRole ko member bana do
                                                        setState(() {
                                                          final idx = channels.indexWhere((c) => c.id == channel.id);
                                                          if (idx != -1) {
                                                            channels[idx] = Channel(
                                                              id: channel.id,
                                                              name: channel.name,
                                                              description: channel.description,
                                                              isPrivate: channel.isPrivate,
                                                              createdAt: channel.createdAt,
                                                              updatedAt: channel.updatedAt,
                                                              createdByName: channel.createdByName,
                                                              createdByAvatar: channel.createdByAvatar,
                                                              members: channel.members,
                                                              joinRequests: channel.joinRequests,
                                                              memberCount: channel.memberCount,
                                                              userRole: 'member',
                                                            );
                                                          }
                                                        });
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Row(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Icon(Icons.check_circle, color: Colors.white, size: 22),
                                                                SizedBox(width: 10),
                                                                Text(
                                                                  'You have joined the channel!',
                                                                  style: TextStyle(
                                                                    color: Colors.white,
                                                                    fontWeight: FontWeight.bold,
                                                                    fontSize: 16,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            backgroundColor: AppTheme.secondaryColor,
                                                            behavior: SnackBarBehavior.floating,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(16),
                                                            ),
                                                            duration: Duration(seconds: 2),
                                                            margin: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                                                          ),
                                                        );
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text(e.toString())),
                                                        );
                                                      } finally {
                                                        setState(() { _joiningChannelId = null; });
                                                      }
                                                    },
                                              icon: _joiningChannelId == channel.id
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                    )
                                                  : const Icon(Icons.group_add_outlined, size: 18, color: Colors.white),
                                              label: Text(
                                                _joiningChannelId == channel.id ? 'Joining...' : 'Join',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                              ),
                                )
                                          else if (channel.isPrivate && hasRequested)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  ),
                                  onPressed: null,
                                  icon: const Icon(Icons.hourglass_empty, size: 18, color: Colors.white),
                                  label: const Text('Requested', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => CreateChannelSheet(
              onCreate: (channel) {
                // channels.add(channel); // Dynamic mein yeh handle hoga
              },
            ),
          );
          if (result == true) {
            _fetchChannels();
          }
        },
        child: const Icon(Icons.add_circle),
        backgroundColor: AppTheme.secondaryColor,
      ),
    );
  }
}

class CreateChannelSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onCreate;
  const CreateChannelSheet({required this.onCreate, Key? key}) : super(key: key);

  @override
  State<CreateChannelSheet> createState() => CreateChannelSheetState();
}

class CreateChannelSheetState extends State<CreateChannelSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool isPublic = true;
  List<Map<String, dynamic>> allContacts = [];
  List<int> selectedContactIds = [];
  bool addAll = true;
  String searchQuery = '';
  bool _isLoading = true;
  String? _error;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final contacts = await ChannelService.getAllContacts();
      setState(() {
        allContacts = contacts;
        selectedContactIds = contacts.map((c) => c['id'] as int).toList();
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
    final filteredContacts = allContacts.where((c) => c['full_name'].toLowerCase().contains(searchQuery.toLowerCase())).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: _isLoading
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
                            'Oops! Unable to load contacts.',
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
                              _fetchContacts();
                            },
                          ),
                        ],
                      ),
                    )
                  : Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const Text('Create Channel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Channel Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter channel name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descController,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Privacy:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('Public'),
                      selected: isPublic,
                      selectedColor: AppTheme.secondaryColor.withOpacity(0.15),
                      onSelected: (v) => setState(() => isPublic = true),
                      labelStyle: TextStyle(color: isPublic ? AppTheme.secondaryColor : Colors.black54),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Private'),
                      selected: !isPublic,
                      selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                      onSelected: (v) => setState(() => isPublic = false),
                      labelStyle: TextStyle(color: !isPublic ? AppTheme.primaryColor : Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Checkbox(
                      value: addAll,
                      onChanged: (v) {
                        setState(() {
                          addAll = v!;
                          if (addAll) {
                            selectedContactIds = allContacts.map((c) => c['id'] as int).toList();
                          } else {
                            selectedContactIds = [];
                          }
                        });
                      },
                      activeColor: AppTheme.secondaryColor,
                    ),
                    const Text('Add all people'),
                  ],
                ),
                if (!addAll)
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search users',
                            prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.primaryColor.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.primaryColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (value) => setState(() => searchQuery = value),
                        ),
                      ),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView(
                      shrinkWrap: true,
                          children: filteredContacts.map((contact) {
                        return CheckboxListTile(
                              value: selectedContactIds.contains(contact['id']),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                    selectedContactIds.add(contact['id'] as int);
                              } else {
                                    selectedContactIds.remove(contact['id'] as int);
                              }
                            });
                          },
                              title: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundImage: contact['profile_picture'] != null && contact['profile_picture'].toString().isNotEmpty
                                        ? NetworkImage(contact['profile_picture'].toString().startsWith('http')
                                            ? contact['profile_picture']
                                            : ApiConfig.getAssetUrl(contact['profile_picture']))
                                        : null,
                                    child: contact['profile_picture'] == null || contact['profile_picture'].toString().isEmpty
                                        ? Text(contact['full_name'][0])
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(contact['full_name']),
                                ],
                              ),
                          activeColor: AppTheme.secondaryColor,
                        );
                      }).toList(),
                    ),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _creating
                        ? null
                        : () async {
                      if (_formKey.currentState!.validate()) {
                              setState(() { _creating = true; });
                              try {
                                await ChannelService.createChannel(
                                  name: _nameController.text.trim(),
                                  description: _descController.text.trim(),
                                  isPrivate: !isPublic,
                                  memberIds: selectedContactIds,
                                );
                                Navigator.pop(context, true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.white, size: 22),
                                        SizedBox(width: 10),
                                        Text(
                                          'Channel created successfully!',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: AppTheme.secondaryColor,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    duration: Duration(seconds: 2),
                                    margin: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                                  ),
                                );
                              } catch (e) {
                                setState(() { _creating = false; });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                      }
                    },
                    child: _creating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create Channel', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
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
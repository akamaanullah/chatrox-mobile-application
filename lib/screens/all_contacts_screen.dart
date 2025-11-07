import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';
import '../constants/theme.dart';
import '../widgets/common_app_bar.dart';
import 'chat_screen.dart';

class AllContactsScreen extends StatefulWidget {
  const AllContactsScreen({Key? key}) : super(key: key);

  @override
  State<AllContactsScreen> createState() => _AllContactsScreenState();
}

class _AllContactsScreenState extends State<AllContactsScreen> {
  List<Contact> _contacts = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final contacts = await ContactService.getAllContacts();
      contacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      setState(() {
        _contacts = contacts;
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
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: CommonAppBar(
            title: 'All Contacts',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(30),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search contacts',
                    border: InputBorder.none,
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
              const SizedBox(height: 12),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor));
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
                _loadContacts();
              },
            ),
          ],
        ),
      );
    }
    final filteredContacts = _searchQuery.isEmpty
        ? _contacts
        : _contacts.where((c) => c.displayName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    if (filteredContacts.isEmpty) {
      return const Center(child: Text('No contacts found'));
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: filteredContacts.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
        final contact = filteredContacts[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            userName: contact.displayName,
                            userAvatar: contact.avatarUrl,
                            chatId: contact.id,
                            userId: contact.id,
                          ),
                        ),
                      );
                    },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
              margin: const EdgeInsets.symmetric(horizontal: 0),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                leading: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE0F2F1),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondaryColor.withOpacity(0.13),
                        blurRadius: 8,
                        spreadRadius: 1,
                            ),
                          ],
                        ),
                  padding: const EdgeInsets.all(2.5),
                  child: _shouldShowAvatarImage(contact)
                      ? CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.transparent,
                          backgroundImage: NetworkImage(contact.avatarUrl),
                        )
                      : CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.7),
                          child: _buildInitials(contact, isWhite: true),
                        ),
                ),
                title: Text(
                  _buildFullName(contact),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                subtitle: Text(
                  '@' + contact.username,
                  style: TextStyle(color: Colors.black45, fontSize: 13.5),
                        ),
                      ),
                    ),
                  ),
                );
              },
    );
  }

  String _buildFullName(Contact contact) {
    String name = (contact.firstName + ' ' + contact.lastName).trim();
    return name.isNotEmpty ? name : '';
  }

  Widget _buildInitials(Contact contact, {bool isWhite = false}) {
    String initials = '';
    if (contact.firstName.isNotEmpty) initials += contact.firstName[0];
    if (contact.lastName.isNotEmpty) initials += contact.lastName[0];
    if (initials.isEmpty && contact.username.isNotEmpty) initials = contact.username[0];
    if (initials.isEmpty) initials = '?';
    return Text(
      initials.toUpperCase(),
      style: TextStyle(
        color: isWhite ? Colors.white : AppTheme.primaryColor,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  bool _shouldShowAvatarImage(Contact contact) {
    final url = contact.avatarUrl.toLowerCase();
    return url.isNotEmpty &&
        !url.contains('default-avatar') &&
        !url.contains('profile.jpg') &&
        !url.contains('default.png');
  }
} 
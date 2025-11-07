import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'chat_screen.dart';
import 'dart:io';
import 'home_screen.dart';

class SelectContactsForMediaScreen extends StatefulWidget {
  final File? imageFile;
  final String? caption;
  const SelectContactsForMediaScreen({Key? key, this.imageFile, this.caption}) : super(key: key);

  @override
  State<SelectContactsForMediaScreen> createState() => _SelectContactsForMediaScreenState();
}

class _SelectContactsForMediaScreenState extends State<SelectContactsForMediaScreen> {
  final List<Map<String, String>> contacts = [
    {'name': 'Ali Khan', 'username': '@alikhan'},
    {'name': 'Sara Ahmed', 'username': '@saraahmed'},
    {'name': 'Usman Tariq', 'username': '@usmantariq'},
    {'name': 'Ayesha Noor', 'username': '@ayeshasmile'},
    {'name': 'Mazhar Gali', 'username': '@mazhar.gali'},
    {'name': 'Jafar', 'username': '@jafar'},
    {'name': 'Shahzaib', 'username': '@shahzaib'},
    {'name': 'Exam Department apt', 'username': '@examdept'},
  ];
  final Set<int> selectedIndexes = {};

  void _toggleSelect(int index) {
    setState(() {
      if (selectedIndexes.contains(index)) {
        selectedIndexes.remove(index);
      } else {
        selectedIndexes.add(index);
      }
    });
  }

  void _sendToSelectedContacts() {
    final selectedContacts = selectedIndexes.map((i) => contacts[i]).toList();
    for (final contact in selectedContacts) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            userName: contact['name']!,
            userAvatar: '',
            chatId: int.parse(contact['id'] ?? '0'),
            userId: int.parse(contact['id'] ?? '0'),
            imageFile: widget.imageFile,
            caption: widget.caption,
          ),
        ),
      );
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        title: Text(
          selectedIndexes.isEmpty ? 'Select contacts' : '${selectedIndexes.length} selected',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(30),
                  shadowColor: AppTheme.primaryColor.withOpacity(0.10),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search contacts',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  itemCount: contacts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    String initials = contact['name']!.isNotEmpty
                        ? contact['name']!.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                        : '';
                    final isSelected = selectedIndexes.contains(index);
                    return Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        splashColor: AppTheme.secondaryColor.withOpacity(0.08),
                        highlightColor: AppTheme.secondaryColor.withOpacity(0.04),
                        onTap: () => _toggleSelect(index),
                        child: Card(
                          elevation: 2,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: AppTheme.primaryColor.withOpacity(0.13),
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppTheme.secondaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(Icons.check, color: Colors.white, size: 18),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact['name']!,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        contact['username']!,
                                        style: TextStyle(color: Colors.black45, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (selectedIndexes.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: selectedIndexes.map((i) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Chip(
                              label: Text(contacts[i]['name']!),
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.13),
                            ),
                          )).toList(),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _sendToSelectedContacts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 0,
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.send, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Send', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
} 
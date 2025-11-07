import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../widgets/common_app_bar.dart';

class StarredMessagesScreen extends StatefulWidget {
  const StarredMessagesScreen({Key? key}) : super(key: key);

  @override
  State<StarredMessagesScreen> createState() => _StarredMessagesScreenState();
}

class _StarredMessagesScreenState extends State<StarredMessagesScreen> {
  late List<Map<String, dynamic>> starredMessages;

  @override
  void initState() {
    super.initState();
    starredMessages = [
      {
        'sender': 'Sir Ashher Baig Apt',
        'avatar': 'https://randomuser.me/api/portraits/men/1.jpg',
        'message': 'https://classroom.google.com/c/NzMxMDcxMDE0Mzkx?cjc=n6yvzp2',
        'time': '3:52 PM',
        'date': '11/18/24',
        'isLink': true,
      },
      {
        'sender': 'You → Khubaib Ahmed',
        'avatar': '',
        'message': 'Account No : 0544306231113\nTitle : Muhammad Zain Ul Abidin\nBranch Code : 0544\nBank : United.Bank Limited\nIBAN : PK45UNIL0109000306231113',
        'time': '11:29 AM',
        'date': '3/5/24',
        'isLink': false,
      },
      {
        'sender': 'Habib Bhai Office → You',
        'avatar': 'https://randomuser.me/api/portraits/men/2.jpg',
        'message': 'Account No : 276278099\nTitle : Master Travel and Tours(Pvt) Ltd\nBranch Code : 0544\nBank : United.Bank Limited\nIBAN : PK34UNIL0109000276278099',
        'time': '3:51 PM',
        'date': '2/27/24',
        'isLink': false,
      },
      {
        'sender': 'Habib Bhai Office → You',
        'avatar': 'https://randomuser.me/api/portraits/men/2.jpg',
        'message': 'Account No : 260323581\nAccount Title : Shaheer Javed\nBranch Code : 0544\nBank : UBL\nIBAN : PK64UNIL0109000260323581',
        'time': '3:51 PM',
        'date': '2/27/24',
        'isLink': false,
      },
      for (int i = 0; i < 18; i++)
        {
          'sender': i % 2 == 0 ? 'You → Zain' : 'Group Chat',
          'avatar': i % 2 == 0 ? '' : 'https://randomuser.me/api/portraits/men/${3 + i}.jpg',
          'message': i % 2 == 0
              ? 'This is a starred message number ${i + 5} from you to Zain.'
              : 'Group message ${i + 5} starred by you.\nAccount: 12345${i}6789',
          'time': '${(i % 12 + 1)}:${(i * 7) % 60} ${i % 2 == 0 ? 'AM' : 'PM'}',
          'date': i < 6 ? '2/27/24' : i < 12 ? '3/5/24' : '11/18/24',
          'isLink': false,
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    String? lastDate;
    return Scaffold(
      backgroundColor: const Color(0xFFF6FDFD),
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
            title: 'Starred',
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
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 120, left: 16, right: 16, bottom: 16),
        itemCount: starredMessages.length,
        itemBuilder: (context, i) {
          final msg = starredMessages[i];
          final showDate = lastDate != msg['date'];
          lastDate = msg['date'];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDate)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg['date'],
                        style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.13),
                    backgroundImage: (msg['avatar'] ?? '').isNotEmpty ? NetworkImage(msg['avatar']) : null,
                    child: (msg['avatar'] ?? '').isEmpty
                        ? Icon(Icons.person, color: AppTheme.primaryColor, size: 22)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onLongPress: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Unstar Message?'),
                            content: const Text('Do you want to remove this message from starred?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Unstar', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          setState(() {
                            starredMessages.removeAt(i);
                          });
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      msg['sender'],
                                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 15),
                                    ),
                                  ),
                                  Icon(Icons.star, color: AppTheme.secondaryColor, size: 20),
                                ],
                              ),
                              const SizedBox(height: 6),
                              msg['isLink']
                                  ? InkWell(
                                      onTap: () {},
                                      child: Text(
                                        msg['message'],
                                        style: TextStyle(color: AppTheme.secondaryColor, decoration: TextDecoration.underline, fontSize: 15),
                                      ),
                                    )
                                  : Text(
                                      msg['message'],
                                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                                    ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    msg['time'],
                                    style: const TextStyle(color: Colors.black45, fontSize: 13),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
} 
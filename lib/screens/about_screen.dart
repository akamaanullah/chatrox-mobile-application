import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/common_app_bar.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

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
            title: 'About App',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 66, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 66),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.13),
                    child: Icon(Icons.chat_bubble_outline, color: AppTheme.primaryColor, size: 44),
                  ),
                  const SizedBox(height: 18),
                  Text('ChatRox', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28, color: AppTheme.primaryColor)),
                  const SizedBox(height: 6),
                  Text('Version 1.0.0', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text('About', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
            const SizedBox(height: 10),
            Text(
              'ChatRox is a modern, secure, and fast messaging application designed for both professional and group communication. With ChatRox, you can enjoy seamless chats, organized channels, and a personalized profile experience. Our platform is built with privacy and user experience in mind, ensuring your conversations are always protected and easily accessible.\n\nKey Features:\n• Real-time messaging and notifications\n• Create and join public or private channels\n• Advanced security and privacy controls\n• User-friendly, modern interface\n• Cross-platform support',
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            Text('Website', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final url = Uri.parse('https://chatrox.com');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not launch website!')),
                  );
                }
              },
              child: Text(
                'https://chatrox.com',
                style: TextStyle(color: AppTheme.secondaryColor, fontSize: 16, decoration: TextDecoration.underline, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
            Text('Copyright', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
            const SizedBox(height: 10),
            Text('© 2024 ChatRox. All rights reserved.', style: TextStyle(fontSize: 15, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
} 
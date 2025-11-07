import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../widgets/common_app_bar.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

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
            title: 'Help & Support',
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
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 66),
            // FAQs Section
            Text('Frequently Asked Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
            const SizedBox(height: 14),
            _faqTile('How do I use the app?', 'Simply log in and start exploring chats, channels, and your profile. Navigate using the bottom bar for quick access to all features.'),
            _faqTile('How can I reset my password?', 'Go to Settings > Security and use the password reset option to securely change your password.'),
            _faqTile('How do I delete my account?', 'If you wish to delete your account, please contact our support team and we will assist you promptly.'),
            const SizedBox(height: 30),
            // Contact Section
            Text('Contact Us', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor)),
            const SizedBox(height: 10),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: Icon(Icons.email_outlined, color: AppTheme.secondaryColor),
                title: const Text('support@chatrox.com'),
                subtitle: const Text('For any queries or support, email us.'),
              ),
            ),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: Icon(Icons.phone_outlined, color: AppTheme.primaryColor),
                title: const Text('+92 300 1234567'),
                subtitle: const Text('Call or WhatsApp us for immediate assistance.'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _faqTile(String question, String answer) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Text(answer, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../widgets/common_app_bar.dart';

class EditLinksScreen extends StatefulWidget {
  const EditLinksScreen({Key? key}) : super(key: key);

  @override
  State<EditLinksScreen> createState() => _EditLinksScreenState();
}

class _EditLinksScreenState extends State<EditLinksScreen> {
  List<Map<String, String>> links = [
    {'type': 'Instagram', 'value': 'akamaanullah'},
  ];

  void _addLink() async {
    // Dummy add link dialog
    final controller = TextEditingController();
    String? type = 'Instagram';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              value: type,
              items: ['Instagram', 'Facebook', 'Twitter', 'LinkedIn']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => type = val,
            ),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Username/Link'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  links.add({'type': type!, 'value': controller.text});
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
            title: 'Edit Links',
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 60, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              const Text(
                'Adding links to your profile helps your contacts easily visit your other profiles.',
                style: TextStyle(color: Colors.black54, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4),
              ),
              const SizedBox(height: 18),
              ...links.map((link) => Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(
                          link['type'] == 'Instagram'
                              ? Icons.camera_alt_outlined
                              : Icons.link,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                        title: Text(link['type'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(link['value'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: () {
                            setState(() {
                              links.remove(link);
                            });
                          },
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.secondaryColor,
                  side: BorderSide(color: AppTheme.secondaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                ),
                onPressed: _addLink,
                icon: const Icon(Icons.add_link),
                label: const Text('Add Link'),
              ),
              const Spacer(),
              const Text(
                'To manage who can see your links, go to privacy settings.',
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {},
                child: Text('privacy settings', style: TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

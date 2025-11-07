import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../widgets/common_app_bar.dart';

class ThemeAppearanceScreen extends StatefulWidget {
  const ThemeAppearanceScreen({Key? key}) : super(key: key);

  @override
  State<ThemeAppearanceScreen> createState() => _ThemeAppearanceScreenState();
}

class _ThemeAppearanceScreenState extends State<ThemeAppearanceScreen> {
  String _themeMode = 'system';

  Color get _activeColor =>
      _themeMode == 'light' ? AppTheme.primaryColor : _themeMode == 'dark' ? AppTheme.secondaryColor : Colors.teal;

  String get _themeLabel =>
      _themeMode == 'light' ? 'Light theme is currently active' : _themeMode == 'dark' ? 'Dark theme is currently active' : 'System theme is currently active';

  IconData get _themeIcon =>
      _themeMode == 'light' ? Icons.wb_sunny_outlined : _themeMode == 'dark' ? Icons.nightlight_round : Icons.phone_android;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FDFD),
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
            title: 'Theme Settings',
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 60, 18, 18),
        children: [
          // Preview Card
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            margin: const EdgeInsets.only(bottom: 18),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.primaryColor)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _activeColor.withOpacity(0.13)),
                    ),
                    child: Column(
                      children: [
                        // Fake AppBar
                        Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: _activeColor,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Icon(Icons.menu, color: Colors.white, size: 22),
                              const SizedBox(width: 10),
                              Text('App Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const Spacer(),
                              Icon(_themeIcon, color: Colors.white, size: 24),
                              const SizedBox(width: 14),
                            ],
                          ),
                        ),
                        // Fake Content
                        Container(
                          height: 38,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Container(
                          height: 18,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        // Fake Bottom Nav
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Icon(Icons.home, color: _activeColor, size: 26),
                              Icon(Icons.explore, color: Colors.grey[400], size: 26),
                              Icon(Icons.person, color: Colors.grey[400], size: 26),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Theme Selection Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 18),
            child: Column(
              children: [
                _themeRadioTile(
                  value: 'light',
                  title: 'Light Theme',
                  subtitle: 'Use light theme always',
                  icon: Icons.wb_sunny_outlined,
                  color: AppTheme.primaryColor,
                ),
                Divider(height: 0, thickness: 1, color: Colors.grey[200]),
                _themeRadioTile(
                  value: 'dark',
                  title: 'Dark Theme',
                  subtitle: 'Use dark theme always',
                  icon: Icons.nightlight_round,
                  color: AppTheme.secondaryColor,
                ),
                Divider(height: 0, thickness: 1, color: Colors.grey[200]),
                _themeRadioTile(
                  value: 'system',
                  title: 'System Theme',
                  subtitle: 'Follow system theme',
                  icon: Icons.phone_android,
                  color: Colors.teal,
                ),
              ],
            ),
          ),
          // Current Theme Info Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Icon(_themeIcon, color: _activeColor, size: 28),
              title: Text('Current Theme Mode', style: TextStyle(fontWeight: FontWeight.bold, color: _activeColor)),
              subtitle: Text(_themeLabel, style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 6,
                shadowColor: AppTheme.secondaryColor.withOpacity(0.3),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Theme settings saved! (dummy action)')),
                );
              },
              child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _themeRadioTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final bool selected = _themeMode == value;
    return Container(
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _themeMode,
        onChanged: (val) => setState(() => _themeMode = val!),
        activeColor: color,
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        subtitle: Text(subtitle),
        secondary: Icon(icon, color: color),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }
} 
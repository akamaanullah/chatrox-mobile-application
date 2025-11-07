import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../widgets/common_app_bar.dart';
import '../services/user_profile_service.dart';

class EditAboutScreen extends StatefulWidget {
  final String currentAbout;
  const EditAboutScreen({Key? key, this.currentAbout = ''}) : super(key: key);

  @override
  State<EditAboutScreen> createState() => _EditAboutScreenState();
}

class _EditAboutScreenState extends State<EditAboutScreen> {
  late String selectedAbout;
  late TextEditingController _customBioController;
  bool _isEditingCustomBio = false;
  bool _isLoading = false;
  final List<String> aboutOptions = [
    'Available',
    'Busy',
    'At school',
    'At the movies',
    'At work',
    'Battery about to die',
    'Can\'t talk, Chatrox only',
    'In a meeting',
    'At the gym',
    'Sleeping',
  ];

  @override
  void initState() {
    super.initState();
    selectedAbout = widget.currentAbout;
    _customBioController = TextEditingController(text: widget.currentAbout);
  }

  @override
  void dispose() {
    _customBioController.dispose();
    super.dispose();
  }

  Future<void> _updateBio(String bio) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await UserProfileService.updateBio(bio);
      if (success) {
        if (mounted) {
          setState(() {
            selectedAbout = bio;
            _customBioController.text = bio;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bio updated successfully',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: EdgeInsets.all(10),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context, bio);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failed to update bio. Please try again.',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: EdgeInsets.all(10),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error: $e',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(10),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _saveCustomBio() async {
    await _updateBio(_customBioController.text);
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
            title: 'Edit Bio',
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
          padding: const EdgeInsets.fromLTRB(18, 50, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              const Text('Currently set to', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                elevation: 4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _isEditingCustomBio
                      ? Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customBioController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter your bio',
                                  border: InputBorder.none,
                                ),
                                maxLines: 2,
                                style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.save, color: Colors.green),
                              onPressed: _saveCustomBio,
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _isEditingCustomBio = false;
                                  _customBioController.text = selectedAbout;
                                });
                              },
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                selectedAbout.isEmpty ? 'No bio set' : selectedAbout,
                                style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit, color: AppTheme.secondaryColor),
                              onPressed: () {
                                setState(() {
                                  _isEditingCustomBio = true;
                                });
                              },
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 28),
              const Text('Select About', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: aboutOptions.length,
                        separatorBuilder: (context, i) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final about = aboutOptions[i];
                          return Material(
                            color: selectedAbout == about ? AppTheme.secondaryColor : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            elevation: selectedAbout == about ? 2 : 0,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _updateBio(about),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        about,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: selectedAbout == about ? FontWeight.bold : FontWeight.w500,
                                          color: selectedAbout == about ? Colors.white : Colors.black87,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    if (selectedAbout == about)
                                      Icon(Icons.check, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final isKeyboardOpen = viewInsets.bottom > 100;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.mainGradient,
        ),
                child: Image.asset(
                  'assets/background.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Blur overlay jab keyboard open ho
            if (isKeyboardOpen)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    color: Colors.white.withOpacity(0.18),
                  ),
                ),
              ),
            SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Back button
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 8),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1e5955), size: 28),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                ),
                  ),
                Expanded(
                  child: Align(
                      alignment: Alignment(0, -0.18),
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                        child: Form(
                          key: _formKey,
                          child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                      const SizedBox(height: 8),
                                      // Logo
                                      Center(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(60),
                                            border: Border.all(color: Colors.white70, width: 2),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.18),
                                                blurRadius: 32,
                                                spreadRadius: 6,
                                                offset: const Offset(0, 16),
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          child: Image.asset(
                                            'assets/icon/platform-icon.png',
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      const Text(
                                        'Reset Password',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF11403a),
                                          letterSpacing: 0.5,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black26,
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      const Text(
                                        'Enter your email address and we will send you instructions to reset your password.',
                                        style: TextStyle(
                                          color: Color(0xFF1e5955),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 28),
                                      _buildUnderlineEmailField(),
                                      const SizedBox(height: 28),
                                      _buildHighlightedResetButton(),
                            ],
                                  ),
                                ),
                              ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnderlineEmailField() {
    return TextFormField(
      controller: _emailController,
      style: const TextStyle(color: Color(0xFF1e5955), fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: const TextStyle(
          color: Color(0xFF11403a),
        fontWeight: FontWeight.bold,
          fontSize: 17,
          shadows: [
            Shadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(0, 1),
            ),
          ],
        ),
        prefixIcon: Icon(Icons.email, color: Color(0xFF1e5955)),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF1e5955), width: 1.2),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF1e5955), width: 2),
        ),
        errorStyle: const TextStyle(color: Color(0xFFB00020), fontWeight: FontWeight.w500),
        ),
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your email';
          }
          if (!value.contains('@')) {
            return 'Please enter a valid email';
          }
          return null;
        },
    );
  }

  Widget _buildHighlightedResetButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1e5955), Color(0xFF2c847e)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      child: ElevatedButton(
        onPressed: _handleResetPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Icon(Icons.arrow_forward, color: Colors.white, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  void _handleResetPassword() {
    if (_formKey.currentState!.validate()) {
      // Add loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      );

      // Simulate reset password delay
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context); // Remove loading indicator
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset link sent to your email'),
            backgroundColor: AppTheme.secondaryColor,
          ),
        );
        
        // Navigate back to login
        Navigator.pop(context);
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }
} 
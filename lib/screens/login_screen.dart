import 'package:flutter/material.dart';
import '../constants/theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import '../utils/storage.dart';
import '../config/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isLoading = false;
  String? _errorMessage;

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
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      // User already logged in, go to home
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
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
            // Top par logo
            Positioned(
              top: 48,
              left: 0,
              right: 0,
              child: Center(
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
                    'assets/icon/platform-icon-1.png',
                    width: 70,
                    height: 70,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Form(
                          key: _formKey,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                const SizedBox(height: 110),
                                const Text(
                                  'Welcome Back',
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF11403a), // Zyada dark green
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
                                const SizedBox(height: 40),
                                _buildUnderlineEmailField(),
                                const SizedBox(height: 24),
                                _buildUnderlinePasswordField(),
                              const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/reset-password');
                                      },
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(color: Color(0xFF1e5955)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                _buildHighlightedSignInButton(),
                                const SizedBox(height: 16),
                                if (_errorMessage != null)
                                  Card(
                                    color: Colors.red[50],
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 0, top: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline, color: Color(0xFFB00020)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _errorMessage!,
                                              style: const TextStyle(color: Color(0xFFB00020), fontSize: 15, fontWeight: FontWeight.w500),
                                            ),
                                          ),
                            ],
                                      ),
                                    ),
                                  ),
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

  Widget _buildUnderlinePasswordField() {
    return TextFormField(
        controller: _passwordController,
        obscureText: true,
      style: const TextStyle(color: Color(0xFF1e5955), fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Password',
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
        prefixIcon: Icon(Icons.lock, color: Color(0xFF1e5955)),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF1e5955), width: 1.2),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF1e5955), width: 2),
        ),
        errorStyle: const TextStyle(color: Color(0xFFB00020), fontWeight: FontWeight.w500),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your password';
          }
          if (value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
    );
  }

  Widget _buildHighlightedSignInButton() {
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
          onPressed: _isLoading ? null : _handleLogin,
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
            children: [
              const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              _isLoading
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.arrow_forward, color: Colors.white, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    print('Login request: $email');
    try {
      final url = Uri.parse(ApiConfig.loginEndpoint);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
      print('Response status: \\${response.statusCode}');
      print('Response body: \\${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final token = data['data']?['token'];
        final userId = data['data']?['user']?['id'];
        if (token != null) {
          print('Login success, token: \\${token}');
          // Save login details in shared preferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          await prefs.setString('email', email);
          await prefs.setString('password', password);
          if (userId != null) {
            await Storage.setUserId(userId);
            print('UserId saved: $userId');
  }
          setState(() {
            _errorMessage = null;
          });
          FocusScope.of(context).unfocus(); // Keyboard dismiss
    Navigator.pushReplacementNamed(context, '/home');
          return;
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Login failed.';
          });
  }
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        final data = json.decode(response.body);
        setState(() {
          _errorMessage = data['message'] ?? 'Invalid email or password.';
        });
      } else {
        setState(() {
          _errorMessage = 'Server error: \\${response.statusCode}';
        });
      }
    } catch (e) {
      print('Login error: $e');
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }
} 
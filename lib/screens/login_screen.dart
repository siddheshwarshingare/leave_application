import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:leave_application/screens/admin_leave_screen.dart';
import 'package:leave_application/screens/dashboard_screen.dart';
import 'package:leave_application/screens/signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _loadRememberedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // REMEMBERED EMAIL
  // ============================================================

  Future<void> _loadRememberedEmail() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      final bool remember = prefs.getBool('rememberMe') ?? false;

      final String savedEmail = prefs.getString('rememberedEmail') ?? '';

      if (!mounted) return;

      if (remember && savedEmail.isNotEmpty) {
        setState(() {
          _rememberMe = true;
          _emailController.text = savedEmail;
        });
      }
    } catch (e) {
      debugPrint('Remembered email error: $e');
    }
  }

  Future<void> _saveRememberMe(String email) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setBool('rememberMe', _rememberMe);

      if (_rememberMe) {
        await prefs.setString('rememberedEmail', email);
      } else {
        await prefs.remove('rememberedEmail');
      }
    } catch (e) {
      debugPrint('Remember me save error: $e');
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String email = _emailController.text.trim();

      final String password = _passwordController.text;

      // ----------------------------------------------------------
      // FIREBASE AUTH
      // ----------------------------------------------------------

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Unable to login. Please try again.');
      }

      final String uid = user.uid;

      // ----------------------------------------------------------
      // REMEMBER ME
      // ----------------------------------------------------------

      await _saveRememberMe(email);

      // ----------------------------------------------------------
      // LOGIN STATE
      // ----------------------------------------------------------

      final SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setBool('isLoggedIn', true);

      await prefs.setString('email', email);

      // ----------------------------------------------------------
      // FCM TOKEN
      // ----------------------------------------------------------

      try {
        final String? token = await FirebaseMessaging.instance.getToken();

        if (token != null && token.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'fcmToken': token,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        debugPrint('FCM token error: $e');
      }

      // ----------------------------------------------------------
      // GET USER PROFILE
      // ----------------------------------------------------------

      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User profile not found.');
      }

      final Map<String, dynamic>? data =
          userDoc.data() as Map<String, dynamic>?;

      final String role = data?['role']?.toString().toLowerCase().trim() ?? '';

      if (!mounted) return;

      // ----------------------------------------------------------
      // NAVIGATION
      // ----------------------------------------------------------

      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminLeaveScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message = 'No account found with this email.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;

        case 'user-disabled':
          message = 'This account has been disabled.';
          break;

        case 'too-many-requests':
          message = 'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Please check your internet connection.';
          break;

        case 'operation-not-allowed':
          message = 'Email/password login is not enabled in Firebase.';
          break;

        default:
          message = e.message ?? 'Login failed. Please try again.';
      }

      if (!mounted) return;

      _showError(message);
    } catch (e) {
      debugPrint('Login error: $e');

      if (!mounted) return;

      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();

    final String email = _emailController.text.trim();

    if (email.isEmpty) {
      _showError('Please enter your email address first.');
      return;
    }

    final bool validEmail = RegExp(
      r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$',
    ).hasMatch(email);

    if (!validEmail) {
      _showError('Please enter a valid email address.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      _showSuccess('Password reset email sent. Please check your inbox.');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message = 'No account found with this email.';
          break;

        case 'network-request-failed':
          message = 'Please check your internet connection.';
          break;

        default:
          message = e.message ?? 'Unable to send password reset email.';
      }

      _showError(message);
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // SUCCESS
  // ============================================================

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // SIGN UP
  // ============================================================

  void _openSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);

    final bool isSmallScreen = size.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),

      resizeToAvoidBottomInset: true,

      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/applogor.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),

              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width < 360 ? 16 : 22,
                  vertical: 14,
                ),

                child: Form(
                  key: _formKey,

                  child: Column(
                    children: [
                      // ==================================================
                      // TOP LOGO
                      // ==================================================
                      SizedBox(
                        height: isSmallScreen ? 125 : 150,

                        child: Center(
                          child: _LoginLogo(size: isSmallScreen ? 86 : 100),
                        ),
                      ),

                      // ==================================================
                      // LOGIN CARD
                      // ==================================================
                      _LoginCard(
                        emailController: _emailController,

                        passwordController: _passwordController,

                        obscurePassword: _obscurePassword,

                        rememberMe: _rememberMe,

                        isLoading: _isLoading,

                        onPasswordVisibilityChanged: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },

                        onRememberChanged: (bool? value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },

                        onForgotPassword: _forgotPassword,

                        onLogin: _login,

                        onSignup: _openSignup,
                      ),

                      const SizedBox(height: 22),

                      // ==================================================
                      // CREATE ACCOUNT
                      // ==================================================
                      _CreateAccountButton(onTap: _openSignup),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// LOGIN LOGO
// ===================================================================

class _LoginLogo extends StatelessWidget {
  final double size;

  const _LoginLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 24,
      height: size + 24,

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(28),

        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C4CF6).withOpacity(0.14),

            blurRadius: 24,

            offset: const Offset(0, 10),
          ),
        ],
      ),

      padding: const EdgeInsets.all(12),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),

        child: Image.asset(
          'assets/Enquadlogosign.jpg',

          fit: BoxFit.cover,

          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6639E9), Color(0xFF0878E8)],
                ),

                borderRadius: BorderRadius.circular(18),
              ),

              child: const Center(
                child: Text(
                  'EN',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ===================================================================
// LOGIN CARD
// ===================================================================

class _LoginCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;

  final bool obscurePassword;
  final bool rememberMe;
  final bool isLoading;

  final VoidCallback onPasswordVisibilityChanged;

  final ValueChanged<bool?> onRememberChanged;

  final VoidCallback onForgotPassword;

  final VoidCallback onLogin;

  final VoidCallback onSignup;

  const _LoginCard({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.rememberMe,
    required this.isLoading,
    required this.onPasswordVisibilityChanged,
    required this.onRememberChanged,
    required this.onForgotPassword,
    required this.onLogin,
    required this.onSignup,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(26),

        border: Border.all(color: const Color(0xFFE9EAF0)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),

            blurRadius: 25,

            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // ========================================================
          // TITLE
          // ========================================================
          const Center(
            child: Text(
              'Welcome Back! 👋',

              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111936),
              ),
            ),
          ),

          const SizedBox(height: 7),

          const Center(
            child: Text(
              'Please login to continue',

              textAlign: TextAlign.center,

              style: TextStyle(fontSize: 13.5, color: Color(0xFF7B8192)),
            ),
          ),

          const SizedBox(height: 26),

          // ========================================================
          // EMAIL LABEL
          // ========================================================
          const _FieldLabel(text: 'Email'),

          const SizedBox(height: 7),

          _InputField(
            controller: emailController,

            hintText: 'Enter your email',

            icon: Icons.email_outlined,

            keyboardType: TextInputType.emailAddress,

            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }

              if (!RegExp(
                r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value.trim())) {
                return 'Enter a valid email';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          // ========================================================
          // PASSWORD LABEL
          // ========================================================
          const _FieldLabel(text: 'Password'),

          const SizedBox(height: 7),

          _InputField(
            controller: passwordController,

            hintText: 'Enter your password',

            icon: Icons.lock_outline,

            obscureText: obscurePassword,

            suffixIcon: IconButton(
              onPressed: onPasswordVisibilityChanged,

              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,

                color: const Color(0xFF8A91A1),
              ),
            ),

            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }

              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }

              return null;
            },

            onSubmitted: (_) {
              if (!isLoading) {
                onLogin();
              }
            },
          ),

          const SizedBox(height: 9),

          // ========================================================
          // REMEMBER + FORGOT
          // ========================================================
          Row(
            children: [
              SizedBox(
                width: 25,
                height: 25,

                child: Checkbox(
                  value: rememberMe,

                  onChanged: onRememberChanged,

                  activeColor: const Color(0xFF6339E9),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),

                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              const SizedBox(width: 6),

              const Expanded(
                child: Text(
                  'Remember me',

                  style: TextStyle(fontSize: 12.5, color: Color(0xFF555B6E)),
                ),
              ),

              GestureDetector(
                onTap: onForgotPassword,

                child: const Text(
                  'Forgot Password?',

                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6339E9),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ========================================================
          // LOGIN BUTTON
          // ========================================================
          SizedBox(
            width: double.infinity,
            height: 54,

            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,

                  colors: [
                    Color(0xFF6339E9),
                    Color(0xFF7548F5),
                    Color(0xFF0878E8),
                  ],
                ),

                borderRadius: BorderRadius.circular(15),

                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6339E9).withOpacity(0.25),

                    blurRadius: 12,

                    offset: const Offset(0, 6),
                  ),
                ],
              ),

              child: ElevatedButton(
                onPressed: isLoading ? null : onLogin,

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,

                  disabledBackgroundColor: Colors.transparent,

                  foregroundColor: Colors.white,

                  disabledForegroundColor: Colors.white,

                  shadowColor: Colors.transparent,

                  elevation: 0,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),

                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,

                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Login',

                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 23),

          // ========================================================
          // DIVIDER
          // ========================================================
          Row(
            children: [
              Expanded(child: Divider(color: const Color(0xFFE2E4EA))),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),

                child: Text(
                  'or continue with',

                  style: TextStyle(fontSize: 12, color: Color(0xFF8A91A1)),
                ),
              ),

              Expanded(child: Divider(color: const Color(0xFFE2E4EA))),
            ],
          ),

          const SizedBox(height: 17),

          // ========================================================
          // GOOGLE + APPLE
          // ========================================================
          Row(
            children: [
              Expanded(
                child: _SocialButton(
                  child: const Text(
                    'G',

                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4285F4),
                    ),
                  ),

                  onTap: () {
                    debugPrint('Google login requires Google Sign-In setup.');
                  },
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _SocialButton(
                  child: const Icon(Icons.apple, size: 25, color: Colors.black),

                  onTap: () {
                    debugPrint('Apple login requires Apple Sign-In setup.');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// FIELD LABEL
// ===================================================================

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,

      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Color(0xFF252B42),
      ),
    );
  }
}

// ===================================================================
// INPUT FIELD
// ===================================================================

class _InputField extends StatelessWidget {
  final TextEditingController controller;

  final String hintText;

  final IconData icon;

  final bool obscureText;

  final Widget? suffixIcon;

  final TextInputType? keyboardType;

  final String? Function(String?)? validator;

  final ValueChanged<String>? onSubmitted;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,

      obscureText: obscureText,

      keyboardType: keyboardType,

      validator: validator,

      onFieldSubmitted: onSubmitted,

      textInputAction: hintText == 'Enter your password'
          ? TextInputAction.done
          : TextInputAction.next,

      style: const TextStyle(fontSize: 14, color: Color(0xFF20263A)),

      decoration: InputDecoration(
        hintText: hintText,

        hintStyle: const TextStyle(color: Color(0xFFA2A7B4), fontSize: 13.5),

        prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 20),

        suffixIcon: suffixIcon,

        filled: true,

        fillColor: const Color(0xFFF9FAFC),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4E6EC)),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE4E6EC)),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6339E9), width: 1.4),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),

        errorStyle: const TextStyle(fontSize: 10.5, color: Colors.redAccent),
      ),
    );
  }
}

// ===================================================================
// SOCIAL BUTTON
// ===================================================================

class _SocialButton extends StatelessWidget {
  final Widget child;

  final VoidCallback onTap;

  const _SocialButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,

      child: Material(
        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        child: InkWell(
          onTap: onTap,

          borderRadius: BorderRadius.circular(14),

          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,

              border: Border.all(color: const Color(0xFFE2E4EA)),

              borderRadius: BorderRadius.circular(14),
            ),

            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// CREATE ACCOUNT
// ===================================================================

class _CreateAccountButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateAccountButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,

      child: RichText(
        textAlign: TextAlign.center,

        text: const TextSpan(
          style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),

          children: [
            TextSpan(text: "Don't have an account? "),

            TextSpan(
              text: "Create Account",
              style: TextStyle(
                color: Color(0xFF6339E9),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

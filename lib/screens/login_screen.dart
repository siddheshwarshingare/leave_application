import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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
  final emailController = TextEditingController();
  bool isLoading = false;
  final _formKey = GlobalKey<FormState>();

  bool rememberMe = false;
  bool obscurePassword = true;
  final passwordController = TextEditingController();
  login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (emailController.text.trim().isEmpty &&
        passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email and password.")),
      );
      return;
    }

    if (emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email address.")),
      );
      return;
    }

    if (passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your password.")),
      );
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      String uid = userCredential.user!.uid;

      SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setBool("isLoggedIn", true);
      await prefs.setString("email", emailController.text.trim());
      await prefs.setString("password", passwordController.text.trim());

      String? token = await FirebaseMessaging.instance.getToken();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        "fcmToken": token,
      });

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      String role = userDoc['role'].toString().toLowerCase();

      if (role == "admin") {
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
    } catch (e) {
      print(e);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// Background Image
          Positioned.fill(
            child: Image.asset("assets/login.jpg", fit: BoxFit.cover),
          ),

          /// Login Form
          Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: 350),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),

                    child: Container(
                      padding: const EdgeInsets.all(20),

                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.90),

                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Column(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          const Text(
                            "Login",

                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 20),
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: "Email",
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "Please enter your email";
                              }

                              if (!RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                              ).hasMatch(value)) {
                                return "Enter a valid email";
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 15),

                          TextFormField(
                            controller: passwordController,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              hintText: "Password",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Please enter your password";
                              }

                              if (value.length < 8) {
                                return "Password must be at least 8 characters";
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 25),

                          SizedBox(
                            width: double.infinity,

                            child: ElevatedButton(
                              onPressed: isLoading ? null : login,

                              child: isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text("Login"),
                            ),
                          ),
                          const SizedBox(height: 11),
                          const Text(
                            "Don'thave an account?",
                            // "Already have an account?",
                            style: TextStyle(color: Colors.grey),
                          ),
                          // TextButton(
                          //   onPressed: () {
                          //     Navigator.pushReplacement(
                          //       context,
                          //       MaterialPageRoute(
                          //         builder: (_) => const LoginScreen(),
                          //       ),
                          //     );
                          //   },
                          //   child: const Text(
                          //     "Login",
                          //     style: TextStyle(
                          //       color: Color(0xff6C63FF),
                          //       fontWeight: FontWeight.bold,
                          //     ),
                          //   ),
                          // ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,

                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(),
                                ),
                              );
                            },

                            child: const Text("Create Account"),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(const MaterialApp(home: PaginationScreen()));
}

class PaginationScreen extends StatefulWidget {
  const PaginationScreen({super.key});

  @override
  State<PaginationScreen> createState() => _PaginationScreenState();
}

class _PaginationScreenState extends State<PaginationScreen> {
  List<int> data = List.generate(50, (i) => i + 1);

  int page = 1;
  int pageSize = 10;

  @override
  Widget build(BuildContext context) {
    int start = (page - 1) * pageSize;
    int end = start + pageSize;

    if (end > data.length) {
      end = data.length;
    }

    List<int> currentData = data.sublist(start, end);

    return Scaffold(
      appBar: AppBar(title: Text("Page $page")),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: currentData.length,
              itemBuilder: (context, index) {
                return ListTile(title: Text("${currentData[index]}"));
              },
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: page > 1 ? () => setState(() => page--) : null,
                child: const Text("Previous"),
              ),

              const SizedBox(width: 20),

              ElevatedButton(
                onPressed: end < data.length
                    ? () => setState(() => page++)
                    : null,
                child: const Text("Next"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

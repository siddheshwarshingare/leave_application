import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:leave_application/screens/login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  final nameController = TextEditingController();

  final phoneController = TextEditingController();

  final emailController = TextEditingController();

  final passwordController = TextEditingController();

  final departmentController = TextEditingController();

  final roleController = TextEditingController();
  List<String> selectedWeeklyOff = [];
  final List<String> weekDays = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  bool loading = false;

  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool isValidPassword(String password) {
    return RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(password);
  }

  signup() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => loading = true);

    try {
      print("STEP 1: Creating auth user...");

      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      print("STEP 2: Auth success");

      String uid = userCredential.user!.uid;

      String? token = await FirebaseMessaging.instance.getToken();

      print("STEP 3: Writing to Firestore...");

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "email": emailController.text.trim(),
        "department": departmentController.text.trim(),
        "role": roleController.text.trim(),
        "weeklyOff": selectedWeeklyOff,
        "fcmToken": token,
        "createdAt": Timestamp.now(),
      });
      await FirebaseFirestore.instance.collection('toatl_leave').doc(uid).set({
        "Cl": "3",
        "Sl": "10",
      });
      print("STEP 4: Firestore success");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account Created Successfully"),
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e, s) {
      print("ERROR: $e");
      print("STACK: $s");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xff9CA3AF), fontSize: 15),
          prefixIcon: Icon(icon, color: const Color(0xff6C63FF), size: 22),
          filled: true,
          fillColor: const Color(0xffF8F9FD),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xffE7EAF3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xff6C63FF), width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Orange Header
            Container(
              height: 1000,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF2563EB), // Blue
                    Color(0xFF1D4ED8),
                  ], //],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(70),
                ),
              ),
            ),

            // Back Button
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ),

            // Heading
            const Positioned(
              top: 10,
              left: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Create Account",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    "Fill in your details to create account",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Floating Icon Card
            Positioned(
              top: 70,
              right: 20,
              child: Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_add_alt_1,
                  color: Color(0xffFF8A00),
                  size: 42,
                ),
              ),
            ),

            /// White Form Card
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 30,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),

                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      children: [
                        buildTextField(
                          controller: nameController,
                          hint: "Full Name",
                          icon: Icons.person_outline_rounded,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Name is required";
                            }
                            return null;
                          },
                        ),

                        buildTextField(
                          controller: phoneController,
                          hint: "Phone Number",
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Phone required";
                            }
                            if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
                              return "Enter valid 10 digit number";
                            }
                            return null;
                          },
                        ),

                        buildTextField(
                          controller: emailController,
                          hint: "Email Address",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Email required";
                            }
                            if (!isValidEmail(value)) {
                              return "Invalid email";
                            }
                            return null;
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: TextFormField(
                            controller: passwordController,
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Password required";
                              }

                              if (!isValidPassword(value)) {
                                return "Minimum 8 characters with letters & numbers";
                              }

                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: "Password",
                              filled: true,
                              fillColor: const Color(0xffF8F9FD),

                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                color: Color(0xff6C63FF),
                              ),

                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),

                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),

                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xffE7EAF3),
                                ),
                              ),

                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: const BorderSide(
                                  color: Color(0xff6C63FF),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            hintText: "Department",
                            prefixIcon: const Icon(
                              Icons.apartment,
                              color: Color(0xff6C63FF),
                            ),
                            filled: true,
                            fillColor: const Color(0xffF8F9FD),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),

                          items: const [
                            DropdownMenuItem(value: "HR", child: Text("HR")),
                            DropdownMenuItem(value: "IT", child: Text("IT")),
                            DropdownMenuItem(
                              value: "Accounts",
                              child: Text("Accounts"),
                            ),
                            DropdownMenuItem(
                              value: "Sales",
                              child: Text("Sales"),
                            ),
                          ],

                          onChanged: (value) {
                            departmentController.text = value!;
                          },
                        ),

                        /// TextFields will come here
                        const SizedBox(height: 18),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            hintText: "Role",
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              color: Color(0xff6C63FF),
                            ),
                            filled: true,
                            fillColor: const Color(0xffF8F9FD),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),

                          items: const [
                            DropdownMenuItem(
                              value: "Admin",
                              child: Text("Admin"),
                            ),
                            DropdownMenuItem(
                              value: "Employee",
                              child: Text("Employee"),
                            ),
                            DropdownMenuItem(
                              value: "Manager",
                              child: Text("Manager"),
                            ),
                          ],

                          onChanged: (value) {
                            roleController.text = value!;
                          },
                        ),
                        const SizedBox(height: 25),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Weekly Off",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff1E2454),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: weekDays.map((day) {
                            return FilterChip(
                              label: Text(day),

                              selected: selectedWeeklyOff.contains(day),

                              selectedColor: const Color(0xff6C63FF),

                              checkmarkColor: Colors.white,

                              labelStyle: TextStyle(
                                color: selectedWeeklyOff.contains(day)
                                    ? Colors.white
                                    : Colors.black87,
                              ),

                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedWeeklyOff.add(day);
                                  } else {
                                    selectedWeeklyOff.remove(day);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 35),

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xff6C63FF), Color(0xff8A7CFF)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x336C63FF),
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: loading ? null : signup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: loading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      "Create Account",
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 25),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account?",
                              style: TextStyle(color: Colors.grey),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Login",
                                style: TextStyle(
                                  color: Color(0xff6C63FF),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
      ),

      // SingleChildScrollView(
      //   child: Padding(
      //     padding: const EdgeInsets.all(20),

      //     child: Form(
      //       key: formKey,

      //       child: Column(
      //         children: [
      //           TextFormField(
      //             controller: nameController,

      //             decoration: const InputDecoration(
      //               labelText: "Full Name",

      //               border: OutlineInputBorder(),
      //             ),

      //             validator: (value) {
      //               if (value == null || value.trim().isEmpty) {
      //                 return "Name is required";
      //               }

      //               return null;
      //             },
      //           ),

      //           const SizedBox(height: 15),

      //           TextFormField(
      //             controller: phoneController,

      //             keyboardType: TextInputType.phone,

      //             decoration: const InputDecoration(
      //               labelText: "Phone Number",

      //               border: OutlineInputBorder(),
      //             ),

      //             validator: (value) {
      //               if (value == null || value.isEmpty) {
      //                 return "Phone required";
      //               }

      //               if (!RegExp(r'^[0-9]{10}$').hasMatch(value)) {
      //                 return "Enter valid 10 digit number";
      //               }

      //               return null;
      //             },
      //           ),

      //           const SizedBox(height: 15),

      //           TextFormField(
      //             controller: emailController,

      //             decoration: const InputDecoration(
      //               labelText: "Email",

      //               border: OutlineInputBorder(),
      //             ),

      //             validator: (value) {
      //               if (value == null || value.isEmpty) {
      //                 return "Email required";
      //               }

      //               if (!isValidEmail(value)) {
      //                 return "Invalid Email";
      //               }

      //               return null;
      //             },
      //           ),

      //           const SizedBox(height: 15),

      //           TextFormField(
      //             controller: passwordController,

      //             obscureText: true,

      //             decoration: const InputDecoration(
      //               labelText: "Password",

      //               border: OutlineInputBorder(),
      //             ),

      //             validator: (value) {
      //               if (value == null || value.isEmpty) {
      //                 return "Password required";
      //               }

      //               if (!isValidPassword(value)) {
      //                 return "Password must contain\n8 chars + alpha numeric";
      //               }

      //               return null;
      //             },
      //           ),

      //           const SizedBox(height: 15),

      //           TextFormField(
      //             controller: departmentController,

      //             decoration: const InputDecoration(
      //               labelText: "Department",

      //               border: OutlineInputBorder(),
      //             ),

      //             validator: (value) {
      //               if (value == null || value.isEmpty) {
      //                 return "Department required";
      //               }

      //               return null;
      //             },
      //           ),

      //           const SizedBox(height: 15),

      //           TextFormField(
      //             controller: roleController,

      //             decoration: const InputDecoration(
      //               labelText: "Role",

      //               border: OutlineInputBorder(),
      //             ),

      //             validator: (value) {
      //               if (value == null || value.isEmpty) {
      //                 return "Role required";
      //               }

      //               return null;
      //             },
      //           ),
      //           const SizedBox(height: 15),

      //           const Align(
      //             alignment: Alignment.centerLeft,
      //             child: Text(
      //               "Weekly Off",
      //               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      //             ),
      //           ),

      //           Wrap(
      //             spacing: 8,
      //             children: weekDays.map((day) {
      //               return FilterChip(
      //                 label: Text(day),

      //                 selected: selectedWeeklyOff.contains(day),

      //                 onSelected: (selected) {
      //                   setState(() {
      //                     if (selected) {
      //                       selectedWeeklyOff.add(day);
      //                     } else {
      //                       selectedWeeklyOff.remove(day);
      //                     }
      //                   });
      //                 },
      //               );
      //             }).toList(),
      //           ),

      //           const SizedBox(height: 30),

      //           SizedBox(
      //             width: double.infinity,

      //             height: 50,

      //             child: ElevatedButton(
      //               onPressed: loading ? null : signup,

      //               child: loading
      //                   ? const CircularProgressIndicator(color: Colors.white)
      //                   : const Text("Create Account"),
      //             ),
      //           ),
      //         ],
      //       ),
      //     ),
      //   ),
      // ),
    );
  }
}

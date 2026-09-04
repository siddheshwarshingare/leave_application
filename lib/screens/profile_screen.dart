import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // ============================================================
  // FIREBASE
  // ============================================================

  User? get currentUser => FirebaseAuth.instance.currentUser;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get userStream {
    final uid = currentUser?.uid;

    if (uid == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // EDIT PROFILE
  // ============================================================

  void _editProfile(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Edit Profile')));
  }

  // ============================================================
  // BUILD
  // ============================================================
  static const Color _orange = Color(0xFFFF6B1A);
  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Text(
            'User not logged in',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ),
      );
    }
    // _ModernSection(
    //   title: "Personal Information",
    //   children: [
    //     _ModernProfileRow(
    //       icon: Icons.email_outlined,
    //       label: "Email",
    //       value: email,
    //     ),
    //     const _ModernDivider(),
    //     _ModernProfileRow(
    //       icon: Icons.phone_outlined,
    //       label: "Phone",
    //       value: phone,
    //     ),
    //   ],
    // ),
    if (currentUser == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: Text(
            'User not logged in',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,

        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFF1F2937),
          ),
        ),

        title: const Text(
          "My Profile",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userStream,

        builder: (context, snapshot) {
          // ----------------------------------------------------
          // LOADING
          // ----------------------------------------------------

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2563EB),
                ),
              ),
            );
          }

          // ----------------------------------------------------
          // ERROR
          // ----------------------------------------------------

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Something went wrong',
                style: TextStyle(fontSize: 13, color: Colors.red.shade400),
              ),
            );
          }

          // ----------------------------------------------------
          // NO DATA
          // ----------------------------------------------------

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Profile data not found',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            );
          }

          // ====================================================
          // FIREBASE DATA
          // ====================================================

          final data = snapshot.data!.data() ?? {};

          final String name = data['name']?.toString().trim().isNotEmpty == true
              ? data['name'].toString().trim()
              : 'Employee';

          final String role = data['role']?.toString().trim().isNotEmpty == true
              ? data['role'].toString().trim()
              : 'Employee';

          final String department =
              data['department']?.toString().trim().isNotEmpty == true
              ? data['department'].toString().trim()
              : '-';

          final String email =
              data['email']?.toString().trim().isNotEmpty == true
              ? data['email'].toString().trim()
              : currentUser!.email ?? '-';

          final String phone =
              data['phone']?.toString().trim().isNotEmpty == true
              ? data['phone'].toString().trim()
              : '-';

          final String employeeId =
              data['employeeId']?.toString().trim().isNotEmpty == true
              ? data['employeeId'].toString().trim()
              : '-';

          final String manager =
              data['manager']?.toString().trim().isNotEmpty == true
              ? data['manager'].toString().trim()
              : '-';

          final String? profileImage =
              data['profileImage']?.toString().trim().isNotEmpty == true
              ? data['profileImage'].toString().trim()
              : null;

          // ====================================================
          // UI
          // ====================================================

          return SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),

              child: Column(
                children: [
                  // ==================================================
                  // MODERN PROFILE HEADER
                  // ==================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF102A56), Color(0xFF173867)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B4DE8).withOpacity(.18),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          right: 120,
                          top: -25,
                          child: Container(
                            height: 80,
                            width: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _orange.withOpacity(.55),
                                width: 1,
                              ),
                            ),
                          ),
                        ),

                        Positioned(
                          right: 70,
                          bottom: -35,
                          child: Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _orange.withOpacity(.45),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            _ProfileAvatar(imageUrl: profileImage, name: name),

                            const SizedBox(height: 12),

                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text(
                              role,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Container(
                            //   padding: const EdgeInsets.symmetric(
                            //     horizontal: 12,
                            //     vertical: 6,
                            //   ),
                            //   decoration: BoxDecoration(
                            //     color: Colors.white.withOpacity(.18),
                            //     borderRadius: BorderRadius.circular(20),
                            //   ),
                            //   child: Text(
                            //     employeeId == '-' ? 'Employee' : 'ID • $employeeId',
                            //     style: const TextStyle(
                            //       color: Colors.white,
                            //       fontSize: 11,
                            //       fontWeight: FontWeight.w600,
                            //     ),
                            //   ),
                            // ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // PERSONAL INFORMATION
                  // ==================================================
                  _ModernSection(
                    title: 'Personal Information',

                    children: [
                      _ModernProfileRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email,
                      ),

                      const _ModernDivider(),

                      _ModernProfileRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: phone,
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // WORK INFORMATION
                  // ==================================================
                  _ModernSection(
                    title: 'Work Information',

                    children: [
                      _ModernProfileRow(
                        icon: Icons.badge_outlined,
                        label: 'Employee ID',
                        value: employeeId,
                      ),

                      const _ModernDivider(),

                      _ModernProfileRow(
                        icon: Icons.business_outlined,
                        label: 'Department',
                        value: department,
                      ),

                      const _ModernDivider(),

                      // _ModernProfileRow(
                      //   icon: Icons.person_outline_rounded,
                      //   label: 'Manager',
                      //   value: manager,
                      // ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // EDIT PROFILE
                  // ==================================================
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _editProfile(context),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text(
                        "Edit Profile",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF173867),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 9),

                  // ==================================================
                  // LOGOUT
                  // ==================================================
                  SizedBox(
                    width: double.infinity,
                    height: 42,

                    child: OutlinedButton(
                      onPressed: () {
                        _showLogoutDialog(context);
                      },

                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        //  backgroundColor: const Color(0xFF6D28D9),
                        foregroundColor: const Color(0xFFDC2626),

                        side: const BorderSide(color: Color(0xFF6D28D9)),

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),

                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: const [
                          Icon(Icons.logout_rounded, size: 17),

                          SizedBox(width: 7),

                          Text(
                            'Logout',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // FOOTER
                  // ==================================================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: Color(0xFF94A3B8),
                      ),

                      const SizedBox(width: 5),

                      Text(
                        'Your information is securely stored',

                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // LOGOUT DIALOG
  // ============================================================

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          title: const Text(
            'Logout',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172033),
            ),
          ),

          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ),

            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                await _logout(context);
              },

              child: const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ==================================================================
// MODERN SECTION
// ==================================================================

class _ModernSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ModernSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: const Color(0xFFE8EDF3)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 5),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 5),

              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),

            ...children,
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// MODERN PROFILE ROW
// ==================================================================

class _ModernProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ModernProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),

      child: Row(
        children: [
          // ICON
          Container(
            width: 30,
            height: 30,

            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),

            child: Icon(icon, size: 15, color: const Color(0xFF64748B)),
          ),

          const SizedBox(width: 10),

          // LABEL
          SizedBox(
            width: 78,

            child: Text(
              label,

              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: Color(0xFF64748B),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // VALUE
          Expanded(
            child: Text(
              value,

              maxLines: 2,

              overflow: TextOverflow.ellipsis,

              textAlign: TextAlign.right,

              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// DIVIDER
// ==================================================================

class _ModernDivider extends StatelessWidget {
  const _ModernDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9));
  }
}

// ==================================================================
// PROFILE AVATAR
// ==================================================================

class _ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;

  const _ProfileAvatar({required this.imageUrl, required this.name});

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'U';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,

      padding: const EdgeInsets.all(2),

      decoration: BoxDecoration(
        shape: BoxShape.circle,

        color: Colors.white,

        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),

      child: ClipOval(
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,

                errorBuilder: (context, error, stackTrace) {
                  return _InitialsAvatar(initials: initials);
                },

                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  );
                },
              )
            : _InitialsAvatar(initials: initials),
      ),
    );
  }
}

// ==================================================================
// INITIALS AVATAR
// ==================================================================

class _InitialsAvatar extends StatelessWidget {
  final String initials;

  const _InitialsAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    const Color _orange = Color(0xFFFF6B1A);
    return Container(
      alignment: Alignment.center,

      decoration: const BoxDecoration(
        color: _orange,
        // gradient: LinearGradient(
        //   colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
        // ),
      ),

      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

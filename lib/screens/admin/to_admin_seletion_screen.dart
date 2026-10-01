// ============================================================
// TO ADMIN SELECTION DIALOG
// ============================================================
import 'package:flutter/material.dart';

class ToAdminSelectionDialog extends StatefulWidget {
  final List<Map<String, String>> admins;
  final Set<String> initialSelection;

  const ToAdminSelectionDialog({
    super.key,
    required this.admins,
    required this.initialSelection,
  });

  @override
  State<ToAdminSelectionDialog> createState() => _ToAdminSelectionDialogState();
}

class _ToAdminSelectionDialogState extends State<ToAdminSelectionDialog> {
  final TextEditingController searchController = TextEditingController();

  late Set<String> selectedEmails;

  List<Map<String, String>> filteredAdmins = [];

  @override
  void initState() {
    super.initState();

    // Copy existing selections
    selectedEmails = Set<String>.from(widget.initialSelection);

    // Initially show all admins
    filteredAdmins = List<Map<String, String>>.from(widget.admins);

    searchController.addListener(_searchAdmins);
  }

  @override
  void dispose() {
    searchController.removeListener(_searchAdmins);
    searchController.dispose();
    super.dispose();
  }

  // ==========================================================
  // TOGGLE ADMIN
  // ==========================================================

  void _toggleAdmin(String email, bool checked) {
    if (!mounted) return;

    setState(() {
      if (checked) {
        selectedEmails.add(email);
      } else {
        selectedEmails.remove(email);
      }
    });

    debugPrint("DIALOG SELECTED ADMINS = $selectedEmails");
  }

  // ==========================================================
  // SEARCH
  // ==========================================================

  void _searchAdmins() {
    final String search = searchController.text.trim().toLowerCase();

    if (!mounted) return;

    setState(() {
      if (search.isEmpty) {
        filteredAdmins = List<Map<String, String>>.from(widget.admins);
        return;
      }

      filteredAdmins = widget.admins.where((admin) {
        final String name = admin['name']?.toLowerCase() ?? '';
        final String email = admin['email']?.toLowerCase() ?? '';

        return name.contains(search) || email.contains(search);
      }).toList();
    });
  }

  // ==========================================================
  // CLEAR SEARCH
  // ==========================================================

  void _clearSearch() {
    searchController.clear();
  }

  // ==========================================================
  // CANCEL
  // ==========================================================

  void _cancel() {
    FocusManager.instance.primaryFocus?.unfocus();

    Navigator.of(context).pop();
  }

  // ==========================================================
  // DONE
  // ==========================================================

  void _done() {
    if (selectedEmails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one admin")),
      );

      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final Set<String> result = Set<String>.from(selectedEmails);

    debugPrint("RETURNING ADMINS = $result");

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),

      // ========================================================
      // TITLE
      // ========================================================
      title: Row(
        children: [
          const Expanded(
            child: Text(
              "Select To Admins",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${selectedEmails.length} selected",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ),

      // ========================================================
      // CONTENT
      // ========================================================
      content: SizedBox(
        width: double.maxFinite,
        height: 480,
        child: Column(
          children: [
            // ====================================================
            // SEARCH
            // ====================================================

            TextField(
              controller: searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: "Search admin name or email",
                prefixIcon: const Icon(Icons.search_rounded),

                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear_rounded),
                      )
                    : null,

                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),

                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ====================================================
            // SELECTED INFO
            // ====================================================
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                selectedEmails.isEmpty
                    ? "No admins selected"
                    : "${selectedEmails.length} admin(s) selected",
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ====================================================
            // ADMIN LIST
            // ====================================================
            Expanded(
              child: filteredAdmins.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 45,
                            color: Color(0xFFCBD5E1),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "No admins found",
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,

                      itemCount: filteredAdmins.length,

                      separatorBuilder: (_, __) {
                        return const Divider(height: 1);
                      },

                      itemBuilder: (context, index) {
                        final Map<String, String> admin = filteredAdmins[index];

                        final String name = admin['name'] ?? '';
                        final String email = admin['email'] ?? '';

                        final bool selected = selectedEmails.contains(email);

                        return CheckboxListTile(
                          dense: true,

                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 0,
                            vertical: 2,
                          ),

                          value: selected,

                          activeColor: const Color(0xFF2563EB),

                          checkColor: Colors.white,

                          controlAffinity: ListTileControlAffinity.leading,

                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          subtitle: Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),

                          onChanged: (bool? value) {
                            _toggleAdmin(email, value ?? false);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ========================================================
      // ACTIONS
      // ========================================================
      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text(
            "Cancel",
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),

        ElevatedButton(
          onPressed: _done,

          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          child: const Text(
            "Done",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final overrideRole = ref.watch(userRoleOverrideProvider);

    return Scaffold(
      backgroundColor: AppTheme.offWhiteBg,
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: currentUser.isManagement
                          ? AppStatusColors.inProgressBg
                          : AppTheme.primaryGreen.withOpacity(0.12),
                      child: Icon(
                        currentUser.isManagement
                            ? Icons.admin_panel_settings_rounded
                            : Icons.person_rounded,
                        size: 42,
                        color: currentUser.isManagement
                            ? AppStatusColors.inProgressText
                            : AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currentUser.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser.email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: currentUser.isManagement
                            ? AppTheme.primaryGreen.withOpacity(0.12)
                            : AppTheme.surfaceWhite,
                        border: Border.all(
                          color: currentUser.isManagement
                              ? AppTheme.primaryGreen
                              : AppTheme.borderLight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        currentUser.isManagement
                            ? 'Role: Management'
                            : 'Role: ${currentUser.role.toUpperCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: currentUser.isManagement
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Role Switcher / Demo Controls Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.tune_rounded,
                            size: 18, color: AppTheme.primaryGreen),
                        SizedBox(width: 8),
                        Text(
                          'Test Role Switcher',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Preview the UI as Student vs. Management before or after setting it in Firestore Console:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Student View')),
                            selected: !currentUser.isManagement,
                            selectedColor: AppTheme.primaryGreen,
                            backgroundColor: AppTheme.surfaceWhite,
                            labelStyle: TextStyle(
                              color: !currentUser.isManagement
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(userRoleOverrideProvider.notifier).state =
                                    'student';
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Management View')),
                            selected: currentUser.isManagement,
                            selectedColor: AppTheme.primaryGreen,
                            backgroundColor: AppTheme.surfaceWhite,
                            labelStyle: TextStyle(
                              color: currentUser.isManagement
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(userRoleOverrideProvider.notifier).state =
                                    'management';
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (overrideRole != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            ref.read(userRoleOverrideProvider.notifier).state =
                                null;
                          },
                          child: const Text('Reset to Firestore Account Role'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Settings & Actions
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notification Preferences'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security_outlined),
                    title: const Text('College Domain & Auth'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: AppStatusColors.reportedText,
                    ),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: AppStatusColors.reportedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      await ref.read(firebaseAuthProvider).signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

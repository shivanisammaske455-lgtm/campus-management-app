import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

/// App shell providing the 5-tab bottom navigation bar with a highlighted
/// circular centre "Report" button, unread alert badges, and minimum 44px touch targets.
class MainShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScreen({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = navigationShell.currentIndex;
    final currentUser = ref.watch(currentUserProvider);
    final unreadAlerts = ref.watch(unreadNotificationCountProvider(currentUser.uid));

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          border: const Border(
            top: BorderSide(color: AppTheme.borderLight, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Tab 0: Home
                _NavButton(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: currentIndex == 0,
                  onTap: () => _onItemTapped(0),
                ),

                // Tab 1: Issues
                _NavButton(
                  icon: Icons.assignment_outlined,
                  activeIcon: Icons.assignment_rounded,
                  label: 'Issues',
                  isSelected: currentIndex == 1,
                  onTap: () => _onItemTapped(1),
                ),

                // Tab 2: Centre Highlighted Circular Report Button
                _CenterReportButton(
                  isSelected: currentIndex == 2,
                  onTap: () => _onItemTapped(2),
                ),

                // Tab 3: Alerts (With live unread badge)
                _NavButton(
                  icon: Icons.notifications_none_rounded,
                  activeIcon: Icons.notifications_rounded,
                  label: 'Alerts',
                  isSelected: currentIndex == 3,
                  badgeCount: unreadAlerts,
                  onTap: () => _onItemTapped(3),
                ),

                // Tab 4: Profile
                _NavButton(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: currentIndex == 4,
                  onTap: () => _onItemTapped(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard navigation item with guaranteed minimum 44px touch target.
class _NavButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary;

    return Semantics(
      label: label,
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppTheme.minTouchTargetSize,
            minHeight: AppTheme.minTouchTargetSize,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? activeIcon : icon,
                      color: color,
                      size: 24,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -2,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFDC2626),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 10,
                            minHeight: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Prominent, circular centre button for "Report" with elevation & high contrast.
class _CenterReportButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _CenterReportButton({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Report Issue',
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 56,
            minHeight: 56,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                ),
                child: const Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Report',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : AppTheme.primaryGreenDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

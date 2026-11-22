import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}';
    } else if (difference.inDays >= 1) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final notificationsAsync =
        ref.watch(userNotificationsStreamProvider(currentUser.uid));
    final unreadCount =
        ref.watch(unreadNotificationCountProvider(currentUser.uid));

    return Scaffold(
      backgroundColor: AppTheme.offWhiteBg,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Alerts & Updates'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount new',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                final firestoreService = ref.read(firestoreServiceProvider);
                await firestoreService.markAllNotificationsAsRead(currentUser.uid);
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userNotificationsStreamProvider(currentUser.uid));
        },
        child: notificationsAsync.when(
          data: (notifications) {
            if (notifications.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 38,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'When management updates the status of your reported issues, you will receive real-time alerts here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(
                  notification: notification,
                  timeAgo: _formatTimeAgo(notification.createdAt),
                  onTap: () async {
                    final firestoreService = ref.read(firestoreServiceProvider);

                    // 1. Mark as read when opened
                    if (!notification.isRead) {
                      await firestoreService.markNotificationAsRead(
                        currentUser.uid,
                        notification.id,
                      );
                    }

                    // 2. Open corresponding issue detail
                    if (context.mounted && notification.issueId.isNotEmpty) {
                      context.push('/issue-detail/${notification.issueId}');
                    }
                  },
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Could not load alerts: $error',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final CampusNotification notification;
  final String timeAgo;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Select visual accent by status
    Color iconColor;
    Color iconBg;
    IconData icon;

    switch (notification.status.toLowerCase()) {
      case 'resolved':
        iconColor = AppStatusColors.resolvedText;
        iconBg = AppStatusColors.resolvedBg;
        icon = Icons.check_circle_rounded;
        break;
      case 'in_progress':
        iconColor = AppStatusColors.inProgressText;
        iconBg = AppStatusColors.inProgressBg;
        icon = Icons.pending_actions_rounded;
        break;
      default:
        iconColor = AppTheme.primaryGreen;
        iconBg = AppTheme.primaryGreen.withOpacity(0.1);
        icon = Icons.notifications_active_rounded;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
      color: notification.isRead ? AppTheme.surfaceWhite : const Color(0xFFFAFBF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: notification.isRead
              ? AppTheme.borderLight
              : AppTheme.primaryGreenLight.withOpacity(0.4),
          width: notification.isRead ? 1.0 : 1.3,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),

              // Title, Body, and Timestamp
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: notification.isRead
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              // Unread Indicator Dot
              if (!notification.isRead) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

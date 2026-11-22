import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable status badge/chip that displays both an icon and a text label
/// (adhering to accessibility guidelines: never color alone).
class StatusChip extends StatelessWidget {
  final IssueStatus status;
  final VoidCallback? onTap;
  final bool isInteractive;

  const StatusChip({
    super.key,
    required this.status,
    this.onTap,
    this.isInteractive = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusStyle = context.statusColors.getStyle(status);

    Widget chipContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusStyle.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusStyle.border,
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusStyle.icon,
            size: 16,
            color: statusStyle.text,
          ),
          const SizedBox(width: 6),
          // Explicit text label requirement: never rely on color alone
          Text(
            status.label,
            style: TextStyle(
              color: statusStyle.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (isInteractive || onTap != null) {
      // Ensure minimum 44px touch target when interactive
      return ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppTheme.minTouchTargetSize,
          minWidth: AppTheme.minTouchTargetSize,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Center(child: chipContent),
        ),
      );
    }

    return chipContent;
  }
}

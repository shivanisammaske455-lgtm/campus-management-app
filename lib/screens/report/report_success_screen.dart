import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// Screen displayed after successful issue submission.
class ReportSuccessScreen extends StatelessWidget {
  final String issueId;
  final String title;
  final String area;

  const ReportSuccessScreen({
    super.key,
    required this.issueId,
    required this.title,
    required this.area,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhiteBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success Badge Icon
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: AppStatusColors.resolvedBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppStatusColors.resolvedBorder,
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 56,
                      color: AppStatusColors.resolvedText,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Main Heading
                Text(
                  'Sent to management',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreenDark,
                      ),
                ),
                const SizedBox(height: 12),

                // Subtitle explanation
                Text(
                  'Thank you for keeping our college campus safe and clean. Your issue report has been received and routed to the maintenance team.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 24),

                // Summary Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _SummaryRow(
                          icon: Icons.title_rounded,
                          label: 'Problem',
                          value: title.isNotEmpty ? title : 'Campus Issue',
                        ),
                        const Divider(height: 20),
                        _SummaryRow(
                          icon: Icons.place_outlined,
                          label: 'Area',
                          value: area,
                        ),
                        const Divider(height: 20),
                        _SummaryRow(
                          icon: Icons.tag_rounded,
                          label: 'Reference ID',
                          value: issueId.length > 8
                              ? issueId.substring(0, 8).toUpperCase()
                              : issueId.toUpperCase(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Button 1: "View my reports"
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.go('/issues');
                    },
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('View my reports'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Button 2: "Back to home"
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.go('/');
                    },
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Back to home'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryGreen),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

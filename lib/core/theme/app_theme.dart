import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/issue_model.dart';
export '../../models/issue_model.dart' show IssueStatus;

/// Color bundle for status chips and banners.
@immutable
class StatusStyle {
  final Color background;
  final Color text;
  final Color border;
  final IconData icon;

  const StatusStyle({
    required this.background,
    required this.text,
    required this.border,
    required this.icon,
  });
}

/// Centralized status colors and styling.
/// - Reported: Red tint
/// - In progress: Amber tint
/// - Resolved: Green tint
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  // Reported: Red tint
  static const Color reportedBg = Color(0xFFFEE2E2);       // Soft red tint
  static const Color reportedText = Color(0xFFB91C1C);     // High-contrast deep red
  static const Color reportedBorder = Color(0xFFFCA5A5);   // Subtle red border

  // In progress: Amber tint
  static const Color inProgressBg = Color(0xFFFEF3C7);     // Soft amber tint
  static const Color inProgressText = Color(0xFFB45309);   // High-contrast deep amber
  static const Color inProgressBorder = Color(0xFFFCD34D); // Subtle amber border

  // Resolved: Green tint
  static const Color resolvedBg = Color(0xFFDCFCE7);       // Soft green tint
  static const Color resolvedText = Color(0xFF15803D);     // High-contrast deep green
  static const Color resolvedBorder = Color(0xFF86EFAC);   // Subtle green border

  final StatusStyle reported;
  final StatusStyle inProgress;
  final StatusStyle resolved;

  const AppStatusColors({
    required this.reported,
    required this.inProgress,
    required this.resolved,
  });

  /// Factory providing default accessible tints for light mode.
  factory AppStatusColors.light() {
    return const AppStatusColors(
      reported: StatusStyle(
        background: reportedBg,
        text: reportedText,
        border: reportedBorder,
        icon: Icons.error_outline_rounded,
      ),
      inProgress: StatusStyle(
        background: inProgressBg,
        text: inProgressText,
        border: inProgressBorder,
        icon: Icons.pending_actions_rounded,
      ),
      resolved: StatusStyle(
        background: resolvedBg,
        text: resolvedText,
        border: resolvedBorder,
        icon: Icons.check_circle_outline_rounded,
      ),
    );
  }

  /// Helper to get style for a given [IssueStatus].
  StatusStyle getStyle(IssueStatus status) {
    switch (status) {
      case IssueStatus.reported:
        return reported;
      case IssueStatus.inProgress:
        return inProgress;
      case IssueStatus.resolved:
        return resolved;
    }
  }

  @override
  AppStatusColors copyWith({
    StatusStyle? reported,
    StatusStyle? inProgress,
    StatusStyle? resolved,
  }) {
    return AppStatusColors(
      reported: reported ?? this.reported,
      inProgress: inProgress ?? this.inProgress,
      resolved: resolved ?? this.resolved,
    );
  }

  @override
  AppStatusColors lerp(ThemeExtension<AppStatusColors>? other, double t) {
    if (other is! AppStatusColors) return this;
    return this; // Tints remain consistent
  }
}

/// Global Application Theme Definition.
class AppTheme {
  // Brand color specifications
  static const Color primaryGreen = Color(0xFF0F5C4A);
  static const Color primaryGreenDark = Color(0xFF0B4537);
  static const Color primaryGreenLight = Color(0xFF1B7F68);
  static const Color offWhiteBg = Color(0xFFF5F6F2);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFE5E7EB);

  // Minimum touch target size (44x44 dp)
  static const double minTouchTargetSize = 44.0;

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme;
    final interTextTheme = GoogleFonts.interTextTheme(baseTextTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        onPrimary: surfaceWhite,
        surface: surfaceWhite,
        onSurface: textPrimary,
      ),
      scaffoldBackgroundColor: offWhiteBg,
      textTheme: interTextTheme,

      // Rounded Cards configuration
      cardTheme: CardTheme(
        color: surfaceWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // 44px minimum touch targets on buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: surfaceWhite,
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: const BorderSide(color: primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTouchTargetSize, minTouchTargetSize),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),

      // Enforce 44px padded touch target size across Material elements
      materialTapTargetSize: MaterialTapTargetSize.padded,

      // Extension for status colors (Reported, In progress, Resolved)
      extensions: [
        AppStatusColors.light(),
      ],
    );
  }
}

/// Extension on BuildContext for quick access to status colors.
extension AppThemeContext on BuildContext {
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>() ?? AppStatusColors.light();
}

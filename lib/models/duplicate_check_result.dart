import 'issue_model.dart';

/// Result returned from Gemini AI duplicate check before issue creation.
class DuplicateCheckResult {
  final bool isDuplicate;
  final String? matchedIssueId;
  final String? reason;
  final Issue? matchedIssue;

  const DuplicateCheckResult({
    required this.isDuplicate,
    this.matchedIssueId,
    this.reason,
    this.matchedIssue,
  });
}

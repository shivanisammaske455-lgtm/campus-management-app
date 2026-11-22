import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/issue_model.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/status_chip.dart';

class ManageIssueScreen extends ConsumerStatefulWidget {
  final String issueId;
  final Issue? initialIssue;

  const ManageIssueScreen({
    super.key,
    required this.issueId,
    this.initialIssue,
  });

  @override
  ConsumerState<ManageIssueScreen> createState() => _ManageIssueScreenState();
}

class _ManageIssueScreenState extends ConsumerState<ManageIssueScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingAfterPhoto = false;
  bool _isUpdatingStatus = false;

  static const List<String> _assignableTeams = [
    'Plumbing team',
    'Electrical team',
    'Housekeeping',
    'Carpentry',
  ];

  Future<void> _assignTeam(Issue issue, String teamName) async {
    final firestoreService = ref.read(firestoreServiceProvider);

    try {
      await firestoreService.updateManagementFields(
        issueId: issue.id,
        status: issue.status,
        assignedTo: teamName,
        afterPhotoUrl: issue.afterPhotoUrl,
        resolvedAt: issue.resolvedAt,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assigned to $teamName.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not assign team: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _markInProgress(Issue issue) async {
    setState(() => _isUpdatingStatus = true);
    final firestoreService = ref.read(firestoreServiceProvider);

    try {
      await firestoreService.updateManagementFields(
        issueId: issue.id,
        status: IssueStatus.inProgress,
        assignedTo: issue.assignedTo,
        afterPhotoUrl: issue.afterPhotoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue marked as In Progress.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppStatusColors.inProgressText,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _pickAndUploadAfterPhoto(Issue issue) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Upload After Photo (Resolution Proof)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppTheme.primaryGreen),
                title: const Text('Capture with Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppTheme.primaryGreen),
                title: const Text('Select from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
      );

      if (image == null) return;

      setState(() => _isUploadingAfterPhoto = true);

      final storageService = ref.read(storageServiceProvider);
      final firestoreService = ref.read(firestoreServiceProvider);

      // Upload to Firebase Storage
      final downloadUrl = await storageService.uploadResolutionPhoto(
        issueId: issue.id,
        photo: image,
      );

      // Save afterPhotoUrl in Firestore
      await firestoreService.updateManagementFields(
        issueId: issue.id,
        status: issue.status,
        assignedTo: issue.assignedTo,
        afterPhotoUrl: downloadUrl,
        resolvedAt: issue.resolvedAt,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('After photo uploaded successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppStatusColors.resolvedText,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload photo: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAfterPhoto = false);
    }
  }

  Future<void> _markResolved(Issue issue) async {
    // Safety check (button is also disabled in UI)
    if (issue.afterPhotoUrl == null || issue.afterPhotoUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must upload an after photo before marking resolved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUpdatingStatus = true);
    final firestoreService = ref.read(firestoreServiceProvider);

    try {
      await firestoreService.updateManagementFields(
        issueId: issue.id,
        status: IssueStatus.resolved,
        assignedTo: issue.assignedTo,
        afterPhotoUrl: issue.afterPhotoUrl,
        resolvedAt: DateTime.now(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue marked as Resolved!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppStatusColors.resolvedText,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not mark resolved: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issueStreamAsync =
        ref.watch(singleIssueStreamProvider(widget.issueId));
    final issue = issueStreamAsync.value ?? widget.initialIssue;

    if (issue == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Issue')),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGreen),
        ),
      );
    }

    final hasAfterPhoto =
        issue.afterPhotoUrl != null && issue.afterPhotoUrl!.isNotEmpty;
    final isAlreadyResolved = issue.status == IssueStatus.resolved;

    return Scaffold(
      backgroundColor: AppTheme.offWhiteBg,
      appBar: AppBar(
        title: Text('Manage Issue #${issue.id.length > 6 ? issue.id.substring(0, 6).toUpperCase() : issue.id}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(child: StatusChip(status: issue.status)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----------------------------------------------------
            // 1. Reporter's Photos
            // ----------------------------------------------------
            const Text(
              'Reporter Photos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (issue.photoUrls.isNotEmpty)
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: issue.photoUrls.length,
                  itemBuilder: (context, index) {
                    final url = issue.photoUrls[index];
                    return Container(
                      width: 150,
                      margin: const EdgeInsets.only(right: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black12,
                            child: const Center(
                              child: Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: const Center(
                  child: Text(
                    'No photos attached by reporter.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // ----------------------------------------------------
            // 2. Title & Description
            // ----------------------------------------------------
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.title.isNotEmpty ? issue.title : 'Campus Issue',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          issue.area,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('•',
                            style: TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(width: 8),
                        Text(
                          issue.category.label,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    if (issue.aiTriage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 18, color: Color(0xFF16A34A)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Gemini AI Triage',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '"${issue.aiTriage!['oneLineSummary'] ?? ''}"',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                  if (issue.aiTriage!['suggestedDepartment'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        'Recommended Team: ${issue.aiTriage!['suggestedDepartment']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF166534),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Text(
                      'Reporter Description:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      issue.description,
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ----------------------------------------------------
            // 3. "Assign to" Chip Row
            // (Plumbing team, Electrical team, Housekeeping, Carpentry)
            // ----------------------------------------------------
            const Text(
              'Assign Maintenance Team',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _assignableTeams.map((team) {
                final isAssigned = issue.assignedTo == team;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAssigned)
                        const Padding(
                          padding: EdgeInsets.only(right: 4.0),
                          child: Icon(Icons.check, size: 14, color: Colors.white),
                        ),
                      Text(team),
                    ],
                  ),
                  selected: isAssigned,
                  selectedColor: AppTheme.primaryGreen,
                  backgroundColor: AppTheme.surfaceWhite,
                  labelStyle: TextStyle(
                    color: isAssigned ? Colors.white : AppTheme.textPrimary,
                    fontWeight: isAssigned ? FontWeight.bold : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isAssigned
                          ? AppTheme.primaryGreen
                          : AppTheme.borderLight,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _assignTeam(issue, team);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ----------------------------------------------------
            // 4. "Mark In Progress" Button
            // ----------------------------------------------------
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _isUpdatingStatus || issue.status == IssueStatus.inProgress
                    ? null
                    : () => _markInProgress(issue),
                icon: const Icon(Icons.pending_actions_rounded),
                label: Text(
                  issue.status == IssueStatus.inProgress
                      ? 'Already In Progress'
                      : 'Mark in progress',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ----------------------------------------------------
            // 5. "Upload After Photo" Button & Preview
            // ----------------------------------------------------
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Resolution Photo (After)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hasAfterPhoto)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppStatusColors.resolvedBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PHOTO ATTACHED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppStatusColors.resolvedText,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (hasAfterPhoto) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          issue.afterPhotoUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _isUploadingAfterPhoto
                            ? null
                            : () => _pickAndUploadAfterPhoto(issue),
                        icon: _isUploadingAfterPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_a_photo_outlined),
                        label: Text(
                          hasAfterPhoto
                              ? 'Change After Photo'
                              : 'Upload after photo',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ----------------------------------------------------
            // 6. "Mark Resolved" Button (Disabled until after photo exists)
            // ----------------------------------------------------
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    // Disabled if no after photo exists OR if update is in progress
                    onPressed: !hasAfterPhoto || _isUpdatingStatus || isAlreadyResolved
                        ? null
                        : () => _markResolved(issue),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(
                      isAlreadyResolved ? 'Issue is Resolved' : 'Mark resolved',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStatusColors.resolvedText,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                    ),
                  ),
                ),
                if (!hasAfterPhoto)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0, left: 4.0),
                    child: Text(
                      '⚠️ "Mark resolved" requires an after photo uploaded above.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStatusColors.reportedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

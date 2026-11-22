import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../core/constants/campus_config.dart';
import '../../core/theme/app_theme.dart';
import '../../models/duplicate_check_result.dart';
import '../../models/issue_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/speech_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/status_chip.dart';
import 'report_success_screen.dart';

enum _DuplicateAction { addMeToo, submitAnyway, cancel }

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // State variables
  final List<XFile> _selectedPhotos = [];
  static const int _maxPhotos = 3;

  String _selectedArea = CampusConfig.defaultCampusAreas.first;
  IssueCategory _selectedCategory = IssueCategory.plumbing;
  IssuePriority _selectedPriority = IssuePriority.medium;

  bool _isDetectingLocation = false;
  String? _locationStatusMessage;

  bool _isListeningSpeech = false;
  bool _isSubmitting = false;
  bool _isCheckingDuplicates = false;
  String _submittingMessage = 'Sending to Management...';

  @override
  void initState() {
    super.initState();
    // Automatically attempt GPS detection on screen open
    _detectLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ==========================================
  // Location Detection
  // ==========================================
  Future<void> _detectLocation() async {
    setState(() {
      _isDetectingLocation = true;
      _locationStatusMessage = null;
    });

    final locationService = ref.read(locationServiceProvider);
    final result = await locationService.detectNearestCampusArea();

    if (!mounted) return;

    setState(() {
      _isDetectingLocation = false;
      if (result.isSuccess && result.nearestArea != null) {
        _selectedArea = result.nearestArea!;
        _locationStatusMessage = 'Auto-detected: ${result.nearestArea}';
      } else {
        _locationStatusMessage = result.userMessage;
      }
    });
  }

  // ==========================================
  // Image Selection & Compression
  // ==========================================
  Future<void> _pickPhoto(ImageSource source) async {
    if (_selectedPhotos.length >= _maxPhotos) {
      _showPoliteSnackBar('You can attach a maximum of $_maxPhotos photos.');
      return;
    }

    try {
      // imageQuality: 70 and maxWidth/Height compress the image before upload
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (image != null) {
        setState(() {
          _selectedPhotos.add(image);
        });
      }
    } catch (e) {
      _showPoliteSnackBar(
        'Could not access ${source == ImageSource.camera ? 'camera' : 'gallery'}. Please check device permissions in Settings.',
      );
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
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
              Text(
                'Add Photo (${_selectedPhotos.length}/$_maxPhotos)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryGreen),
                title: const Text('Take Photo with Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryGreen),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  // ==========================================
  // Voice Input (Speech to Text)
  // ==========================================
  Future<void> _toggleVoiceInput() async {
    final speechService = ref.read(speechServiceProvider);

    if (_isListeningSpeech) {
      await speechService.stopListening();
      setState(() {
        _isListeningSpeech = false;
      });
      return;
    }

    setState(() {
      _isListeningSpeech = true;
    });

    await speechService.startListening(
      onResult: (words) {
        setState(() {
          if (_descriptionController.text.isEmpty) {
            _descriptionController.text = words;
          } else {
            // Append or replace
            _descriptionController.text = words;
          }
          _descriptionController.selection = TextSelection.fromPosition(
            TextPosition(offset: _descriptionController.text.length),
          );
        });
      },
      onError: (message) {
        setState(() {
          _isListeningSpeech = false;
        });
        _showPoliteSnackBar(message);
      },
    );
  }

  // ==========================================
  // Submit Issue (with duplicate check)
  // ==========================================
  Future<void> _submitReport() async {
    // 1. Validation: At least one photo required
    if (_selectedPhotos.isEmpty) {
      _showPoliteSnackBar('Please attach at least one photo showing the problem.');
      return;
    }

    // 2. Validation: Description required
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showPoliteSnackBar('Please provide a short description of the issue.');
      return;
    }

    // Default title if left blank
    String title = _titleController.text.trim();
    if (title.isEmpty) {
      title = '${_selectedCategory.label} issue in $_selectedArea';
    }

    final firestoreService = ref.read(firestoreServiceProvider);
    final currentUser = ref.read(currentUserProvider);

    // ----------------------------------------------------------------
    // STEP A: Duplicate check BEFORE photo upload
    // We check first to avoid uploading orphaned photos to Storage.
    // ----------------------------------------------------------------
    setState(() {
      _isSubmitting = true;
      _isCheckingDuplicates = true;
      _submittingMessage = 'Checking for similar reports...';
    });

    DuplicateCheckResult duplicateResult;
    try {
      duplicateResult = await firestoreService.checkForDuplicateIssue(
        area: _selectedArea,
        title: title,
        description: description,
      );
    } catch (_) {
      // If the check itself fails, treat as no duplicate and continue
      duplicateResult = DuplicateCheckResult(isDuplicate: false);
    }

    if (!mounted) return;

    setState(() {
      _isCheckingDuplicates = false;
      _isSubmitting = false; // Pause overlay while showing dialog
    });

    // ----------------------------------------------------------------
    // STEP B: If a duplicate was found, show the bottom sheet
    // ----------------------------------------------------------------
    if (duplicateResult.isDuplicate && duplicateResult.matchedIssue != null) {
      final action = await _showDuplicateSheet(
        matchedIssue: duplicateResult.matchedIssue!,
        reason: duplicateResult.reason ?? 'This may describe the same problem.',
      );

      if (!mounted) return;

      if (action == _DuplicateAction.cancel) {
        // User dismissed — do nothing
        return;
      }

      if (action == _DuplicateAction.addMeToo) {
        // Add uid to meTooBy and navigate to the existing issue
        try {
          await firestoreService.toggleMeToo(
            issueId: duplicateResult.matchedIssue!.id,
            uid: currentUser.uid,
            isCurrentlyAdded: false,
          );
        } catch (_) {
          // Non-critical — still navigate even if toggle failed
        }
        if (!mounted) return;
        context.go(
          '/issue-detail/${duplicateResult.matchedIssue!.id}',
          extra: duplicateResult.matchedIssue,
        );
        return;
      }

      // action == _DuplicateAction.submitAnyway → fall through to upload
    }

    // ----------------------------------------------------------------
    // STEP C: Upload photos and create the new issue
    // ----------------------------------------------------------------
    setState(() {
      _isSubmitting = true;
      _submittingMessage = 'Uploading photos...';
    });

    try {
      final storageService = ref.read(storageServiceProvider);

      // Temporary ID placeholder for storage folder path
      final tempIssueId = DateTime.now().millisecondsSinceEpoch.toString();

      // Upload compressed photos to Firebase Storage
      final photoUrls = await storageService.uploadIssuePhotos(
        issueId: tempIssueId,
        photos: _selectedPhotos,
      );

      setState(() {
        _submittingMessage = 'Sending to Management...';
      });

      // Build Issue model with status: reported
      final newIssue = Issue(
        id: '',
        title: title,
        description: description,
        area: _selectedArea,
        category: _selectedCategory,
        priority: _selectedPriority,
        status: IssueStatus.reported,
        photoUrls: photoUrls,
        reportedBy: currentUser.uid,
        reporterName: currentUser.displayName,
        assignedTo: '',
        afterPhotoUrl: null,
        meTooBy: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save to Firestore (triggers Cloud Function for email + AI triage)
      final createdDocId = await firestoreService.createIssue(newIssue);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      // Navigate to success screen via GoRouter
      context.go(
        '/report-success',
        extra: {
          'issueId': createdDocId,
          'title': title,
          'area': _selectedArea,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      _showPoliteSnackBar('Could not submit report. Please check your connection and try again.');
    }
  }

  // ==========================================
  // Duplicate Issue Bottom Sheet
  // ==========================================
  /// Shows a modal bottom sheet describing the matched issue.
  /// Returns [_DuplicateAction] based on user's choice.
  Future<_DuplicateAction> _showDuplicateSheet({
    required Issue matchedIssue,
    required String reason,
  }) async {
    final result = await showModalBottomSheet<_DuplicateAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _DuplicateIssueSheet(
        matchedIssue: matchedIssue,
        reason: reason,
      ),
    );
    // If user dismisses by swiping down, treat as cancel
    return result ?? _DuplicateAction.cancel;
  }

  void _showPoliteSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppTheme.textPrimary,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Campus Issue'),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ----------------------------------------------------
                  // 1. Photos Section (up to 3 photos, camera/gallery)
                  // ----------------------------------------------------
                  _SectionHeader(
                    title: 'Photos of the Problem',
                    subtitle: 'Attach up to 3 clear photos (*At least 1 required)',
                    icon: Icons.photo_camera_outlined,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 105,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Display picked photos
                        ..._selectedPhotos.asMap().entries.map((entry) {
                          final index = entry.key;
                          final photo = entry.value;
                          return _PhotoThumbnail(
                            photo: photo,
                            onRemove: () => _removePhoto(index),
                          );
                        }),
                        // Add photo button if < 3
                        if (_selectedPhotos.length < _maxPhotos)
                          _AddPhotoButton(
                            currentCount: _selectedPhotos.length,
                            maxCount: _maxPhotos,
                            onTap: _showImageSourcePicker,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ----------------------------------------------------
                  // 2. Campus Location Section (GPS + Override Chips)
                  // ----------------------------------------------------
                  _SectionHeader(
                    title: 'Campus Area',
                    subtitle: 'Detected via GPS or select to override',
                    icon: Icons.place_outlined,
                    trailing: TextButton.icon(
                      onPressed: _isDetectingLocation ? null : _detectLocation,
                      icon: _isDetectingLocation
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location, size: 16),
                      label: Text(
                        _isDetectingLocation ? 'Locating...' : 'Re-detect',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  if (_locationStatusMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        _locationStatusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _locationStatusMessage!.contains('Auto-detected')
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: CampusConfig.defaultCampusAreas.map((area) {
                      final isSelected = _selectedArea == area;
                      return ChoiceChip(
                        label: Text(area),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryGreen,
                        backgroundColor: AppTheme.surfaceWhite,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : AppTheme.borderLight,
                          ),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedArea = area;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // ----------------------------------------------------
                  // 3. Issue Title (Optional, has smart default)
                  // ----------------------------------------------------
                  _SectionHeader(
                    title: 'Short Title',
                    subtitle: 'Brief summary of the issue',
                    icon: Icons.title_rounded,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Pipe leakage in garden pathway',
                      filled: true,
                      fillColor: AppTheme.surfaceWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.borderLight),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ----------------------------------------------------
                  // 4. Description with Voice Input Button
                  // ----------------------------------------------------
                  _SectionHeader(
                    title: 'Description',
                    subtitle: 'Describe the issue or speak using the mic button',
                    icon: Icons.notes_rounded,
                    trailing: InkWell(
                      onTap: _toggleVoiceInput,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isListeningSpeech
                              ? AppStatusColors.reportedBg
                              : AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isListeningSpeech
                                ? AppStatusColors.reportedBorder
                                : AppTheme.primaryGreenLight,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isListeningSpeech ? Icons.mic : Icons.mic_none,
                              size: 16,
                              color: _isListeningSpeech
                                  ? AppStatusColors.reportedText
                                  : AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isListeningSpeech ? 'Listening...' : 'Voice Input',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _isListeningSpeech
                                    ? AppStatusColors.reportedText
                                    : AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    minLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Provide details (location landmark, severity, safety hazard)...',
                      filled: true,
                      fillColor: AppTheme.surfaceWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.borderLight),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.borderLight),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ----------------------------------------------------
                  // 5. Category Chip Row
                  // ----------------------------------------------------
                  _SectionHeader(
                    title: 'Category',
                    subtitle: 'Choose category of maintenance',
                    icon: Icons.category_outlined,
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: IssueCategory.values.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(cat.label),
                            selected: isSelected,
                            selectedColor: AppTheme.primaryGreen,
                            backgroundColor: AppTheme.surfaceWhite,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? AppTheme.primaryGreen
                                    : AppTheme.borderLight,
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = cat;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ----------------------------------------------------
                  // 6. Priority Chip Row
                  // ----------------------------------------------------
                  _SectionHeader(
                    title: 'Priority',
                    subtitle: 'Select urgency level',
                    icon: Icons.flag_outlined,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: IssuePriority.values.map((priority) {
                      final isSelected = _selectedPriority == priority;
                      Color activeColor;
                      switch (priority) {
                        case IssuePriority.urgent:
                          activeColor = AppStatusColors.reportedText;
                          break;
                        case IssuePriority.medium:
                          activeColor = AppStatusColors.inProgressText;
                          break;
                        case IssuePriority.low:
                          activeColor = AppTheme.primaryGreen;
                          break;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(priority.label),
                          selected: isSelected,
                          selectedColor: activeColor,
                          backgroundColor: AppTheme.surfaceWhite,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? activeColor : AppTheme.borderLight,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedPriority = priority;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  // ----------------------------------------------------
                  // 7. Submit Button (Min 44px target)
                  // ----------------------------------------------------
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitReport,
                      icon: const Icon(Icons.send_rounded),
                      label: const Text(
                        'Submit Issue to Management',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ----------------------------------------------------
          // Loading Overlay (duplicate check + submission)
          // ----------------------------------------------------
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.45),
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Show a search icon during duplicate check, spinner otherwise
                        if (_isCheckingDuplicates)
                          const Icon(Icons.search_rounded, size: 36, color: AppTheme.primaryGreen)
                        else
                          const CircularProgressIndicator(color: AppTheme.primaryGreen),
                        const SizedBox(height: 16),
                        Text(
                          _submittingMessage,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isCheckingDuplicates
                              ? 'Gemini is scanning recent reports in this area'
                              : 'Compressing photos and filing report',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// Helper Widgets
// ----------------------------------------------------
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final XFile photo;
  final VoidCallback onRemove;

  const _PhotoThumbnail({
    required this.photo,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 95,
      height: 95,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: kIsWeb
                ? Image.network(
                    photo.path,
                    width: 95,
                    height: 95,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(photo.path),
                    width: 95,
                    height: 95,
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final int currentCount;
  final int maxCount;
  final VoidCallback onTap;

  const _AddPhotoButton({
    required this.currentCount,
    required this.maxCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 95,
        height: 95,
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryGreenLight,
            style: BorderStyle.solid,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_a_photo_outlined,
              color: AppTheme.primaryGreen,
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              'Add Photo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryGreenDark,
              ),
            ),
            Text(
              '$currentCount/$maxCount',
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Duplicate Issue Bottom Sheet
// ============================================================
/// Full-featured modal sheet shown when Gemini detects a possible duplicate.
/// Returns [_DuplicateAction] depending on what the user taps.
class _DuplicateIssueSheet extends StatelessWidget {
  final Issue matchedIssue;
  final String reason;

  const _DuplicateIssueSheet({
    required this.matchedIssue,
    required this.reason,
  });

  @override
  Widget build(BuildContext context) {
    final meTooCount = matchedIssue.meTooBy.length;
    final timeAgo = _formatTimeAgo(matchedIssue.createdAt);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        // Ensure content clears the keyboard if open
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag handle ──
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Gemini AI header banner ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryGreenLight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Gemini detected a similar issue',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryGreenDark,
                        ),
                      ),
                      Text(
                        'A recent report in this area may describe the same problem.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── AI reason text ──
          Text(
            reason,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),

          // ── Matched issue preview card ──
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(13),
                    bottomLeft: Radius.circular(13),
                  ),
                  child: matchedIssue.photoUrls.isNotEmpty
                      ? Image.network(
                          matchedIssue.photoUrls.first,
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _PlaceholderThumb(),
                        )
                      : _PlaceholderThumb(),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          matchedIssue.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${matchedIssue.area} · $timeAgo',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            StatusChip(status: matchedIssue.status),
                            if (meTooCount > 0) ...[
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.people_outline,
                                    size: 14,
                                    color: AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$meTooCount ${meTooCount == 1 ? 'person' : 'people'} also affected',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Primary action: Add Me Too ──
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(context).pop(_DuplicateAction.addMeToo),
              icon: const Icon(Icons.people_rounded, size: 20),
              label: const Text(
                'Same problem — add me too',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Secondary action: Submit anyway ──
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(context).pop(_DuplicateAction.submitAnyway),
              icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.primaryGreen),
              label: const Text(
                'Different problem — submit anyway',
                style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // ── Tertiary: Cancel ──
          TextButton(
            onPressed: () => Navigator.of(context).pop(_DuplicateAction.cancel),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a friendly relative time string, e.g. "2h ago", "3d ago"
  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Placeholder thumbnail shown when a photo URL is missing or fails to load
class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      color: AppTheme.primaryGreen.withOpacity(0.1),
      child: const Icon(Icons.image_not_supported_outlined, color: AppTheme.textSecondary, size: 28),
    );
  }
}

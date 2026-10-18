import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sprig_mascot.dart';
import '../../auth/data/auth_providers.dart';
import '../data/campus_locations_repository.dart';
import '../data/reports_provider.dart';
import '../data/reports_repository.dart';
import '../domain/ai_analysis_models.dart';
import '../domain/duplicate_detection_models.dart';
import '../domain/campus_location_models.dart';
import '../domain/report_model.dart';
import '../../reports_tracking/presentation/report_detail_screen.dart';
import '../../map/data/campus_map_provider.dart';
import '../../rewards/data/eco_points_provider.dart';
import '../../rewards/data/achievements_provider.dart';
import '../../rewards/data/challenges_provider.dart';
import '../../rewards/domain/eco_points_model.dart';

const int kMaxPhotoSizeBytes = 8 * 1024 * 1024; // 8 MB limit

enum LocationCaptureStatus { getting, attached, unavailable }

class ReportIssueScreen extends ConsumerStatefulWidget {
  final String? initialBuildingName;

  const ReportIssueScreen({
    super.key,
    this.initialBuildingName,
  });

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locationDetailsController;
  late TextEditingController _manualFloorController;

  IssueCategory _selectedCategory = IssueCategory.waste;
  IssueSeverity _selectedSeverity = IssueSeverity.medium;

  // Selected Location State
  CampusBuilding? _selectedBuilding;
  CampusFloor? _selectedFloor;
  double? _deviceLatitude;
  double? _deviceLongitude;
  LocationCaptureStatus _locationStatus = LocationCaptureStatus.getting;

  // Selected Photo State
  XFile? _pickedFile;
  Uint8List? _photoBytes;
  String? _photoMimeType;
  String? _photoError;

  // AI Understanding State
  bool _isAnalyzing = false;
  AiIssueAnalysis? _aiAnalysis;
  String? _aiAnalysisError;
  bool _titleEditedByUser = false;
  bool _descEditedByUser = false;
  bool _categoryEditedByUser = false;
  bool _severityEditedByUser = false;

  // Intelligent Duplicate Detection State
  bool _isCheckingDuplicates = false;
  DuplicateCheckResult? _duplicateResult;
  bool _duplicateCheckStale = true;
  String? _lastCheckedSignature;

  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  void _invalidateDuplicateCheck() {
    _duplicateCheckStale = true;
    _lastCheckedSignature = null;
    _duplicateResult = null;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();
    _locationDetailsController = TextEditingController();
    _manualFloorController = TextEditingController();

    _titleController.addListener(() {
      if (!_isAnalyzing) {
        _invalidateDuplicateCheck();
      }
    });
    _descController.addListener(() {
      if (!_isAnalyzing) {
        _invalidateDuplicateCheck();
      }
    });
    _locationDetailsController.addListener(() {
      _invalidateDuplicateCheck();
    });
    _manualFloorController.addListener(() {
      _invalidateDuplicateCheck();
    });

    _captureLocation();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationDetailsController.dispose();
    _manualFloorController.dispose();
    super.dispose();
  }

  /// Automatically captures device coordinates with permission and fallback.
  Future<void> _captureLocation() async {
    if (!mounted) return;
    setState(() {
      _locationStatus = LocationCaptureStatus.getting;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationStatus = LocationCaptureStatus.unavailable;
            _deviceLatitude = null;
            _deviceLongitude = null;
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _locationStatus = LocationCaptureStatus.unavailable;
              _deviceLatitude = null;
              _deviceLongitude = null;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationStatus = LocationCaptureStatus.unavailable;
            _deviceLatitude = null;
            _deviceLongitude = null;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _deviceLatitude = position.latitude;
          _deviceLongitude = position.longitude;
          _locationStatus = LocationCaptureStatus.attached;
        });
      }
    } catch (e) {
      debugPrint('Automatic location capture error: $e');
      if (mounted) {
        setState(() {
          _locationStatus = LocationCaptureStatus.unavailable;
          _deviceLatitude = null;
          _deviceLongitude = null;
        });
      }
    }
  }

  Widget _buildLocationStatusBadge() {
    Color bgColor;
    Color borderColor;
    Widget iconWidget;
    String statusText;
    Widget? trailingAction;

    switch (_locationStatus) {
      case LocationCaptureStatus.attached:
        bgColor = const Color(0xFFF0FDF4);
        borderColor = const Color(0xFFBBF7D0);
        iconWidget = const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A));
        statusText = _deviceLatitude != null && _deviceLongitude != null
            ? 'Location attached (${_deviceLatitude!.toStringAsFixed(4)}, ${_deviceLongitude!.toStringAsFixed(4)})'
            : 'Location attached';
        trailingAction = null;
        break;
      case LocationCaptureStatus.getting:
        bgColor = const Color(0xFFF8FAFC);
        borderColor = const Color(0xFFE2E8F0);
        iconWidget = const Icon(Icons.location_searching_rounded, size: 16, color: AppColors.primary);
        statusText = 'Getting location…';
        trailingAction = null;
        break;
      case LocationCaptureStatus.unavailable:
        bgColor = const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFFECACA);
        iconWidget = const Icon(Icons.location_off_outlined, size: 16, color: Color(0xFFDC2626));
        statusText = 'Location unavailable';
        trailingAction = InkWell(
          onTap: _captureLocation,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 13, color: AppColors.primary),
                SizedBox(width: 3),
                Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          iconWidget,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.inkPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingAction != null) trailingAction,
        ],
      ),
    );
  }

  bool _isManualFloorBuilding(CampusBuilding? b) {
    if (b == null) return false;
    final nameLower = b.name.toLowerCase();
    // Hostels or buildings without predefined floors in Supabase
    return nameLower.contains('hostel') ||
        (b.name != 'Engineering Block' && b.name != 'New Engineering Block');
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _photoError = null);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (bytes.length > kMaxPhotoSizeBytes) {
        setState(() {
          _photoError = 'Photo exceeds 8 MB limit (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB). Please select a smaller photo.';
        });
        return;
      }

      // Check MIME type or extension
      final mime = picked.mimeType ?? _sniffMimeType(picked.name);
      final allowedMimes = ['image/jpeg', 'image/png', 'image/webp'];
      if (!allowedMimes.contains(mime.toLowerCase())) {
        setState(() {
          _photoError = 'Unsupported format ($mime). Please select JPEG, PNG, or WebP.';
        });
        return;
      }

      setState(() {
        _pickedFile = picked;
        _photoBytes = bytes;
        _photoMimeType = mime;
        _photoError = null;
      });
    } catch (e) {
      setState(() {
        _photoError = 'Failed to access camera/gallery: $e';
      });
    }
  }

  String _sniffMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _clearPhoto() {
    setState(() {
      _pickedFile = null;
      _photoBytes = null;
      _photoMimeType = null;
      _photoError = null;
      _aiAnalysis = null;
      _aiAnalysisError = null;
      _invalidateDuplicateCheck();
    });
  }

  /// Triggers AI Issue Understanding via Edge Function.
  Future<void> _runAiAnalysis() async {
    if (_photoBytes == null || _photoMimeType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or capture a photo first to analyze.'),
          backgroundColor: AppColors.severityCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _aiAnalysisError = null;
    });

    try {
      final repo = ref.read(reportsRepositoryProvider);
      final analysis = await repo.analyzeReport(
        photoBytes: _photoBytes!,
        photoMimeType: _photoMimeType!,
        userDescription: _descController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isAnalyzing = false;
        _aiAnalysis = analysis;
        _aiAnalysisError = null;

        // Populate fields if student has not manually customized them
        if (!_titleEditedByUser || _titleController.text.trim().isEmpty) {
          _titleController.text = analysis.issueTitle;
          _titleEditedByUser = false;
        }
        if (!_descEditedByUser || _descController.text.trim().isEmpty) {
          _descController.text = analysis.issueDescription;
          _descEditedByUser = false;
        }
        if (!_categoryEditedByUser) {
          _selectedCategory = analysis.category;
          _categoryEditedByUser = false;
          _invalidateDuplicateCheck();
        }
        if (!_severityEditedByUser) {
          _selectedSeverity = analysis.severity;
          _severityEditedByUser = false;
        }

        _invalidateDuplicateCheck();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  analysis.needsReview
                      ? 'AI suggestions generated (Review recommended)'
                      : 'AI suggestions applied (${analysis.confidence.toUpperCase()} confidence)',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e is AiAnalysisException ? e.message : 'AI analysis is temporarily unavailable: $e';
      setState(() {
        _isAnalyzing = false;
        _aiAnalysis = null;
        _aiAnalysisError = errorMessage;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Manually checks for similar active reports before final submission.
  Future<void> _runManualDuplicateCheck() async {
    if (_isCheckingDuplicates) return;

    if (_selectedBuilding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a campus building first to check for duplicates.'),
          backgroundColor: AppColors.severityCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isManual = _isManualFloorBuilding(_selectedBuilding);
    setState(() => _isCheckingDuplicates = true);

    final signature = '${_selectedBuilding?.id}_${_selectedCategory.name}_${_titleController.text.trim().toLowerCase()}_${_descController.text.trim().toLowerCase()}_${_selectedFloor?.id}_${_manualFloorController.text.trim().toLowerCase()}_${_locationDetailsController.text.trim().toLowerCase()}';

    try {
      final repo = ref.read(reportsRepositoryProvider);
      final result = await repo.checkDuplicates(
        buildingId: _selectedBuilding!.id,
        category: _selectedCategory,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        floorId: !isManual ? _selectedFloor?.id : null,
        floorText: isManual ? _manualFloorController.text.trim() : null,
        locationDetails: _locationDetailsController.text.trim().isNotEmpty
            ? _locationDetailsController.text.trim()
            : null,
      );

      if (!mounted) return;
      setState(() {
        _isCheckingDuplicates = false;
        _duplicateResult = result;
        _lastCheckedSignature = signature;
        _duplicateCheckStale = false;
      });

      if (result.hasMatch) {
        _showDuplicateWarningModal(result);
      } else if (result.outcome == DuplicateOutcome.noMatch) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('No similar active report found in ${_selectedBuilding!.name}.'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Duplicate check is temporarily unavailable.'),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingDuplicates = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicate check error: $e'),
          backgroundColor: AppColors.severityCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Primary submission handler: validates form, executes duplicate check, and shows warning if matched.
  void _submitReport() async {
    if (_isSubmitting || _isCheckingDuplicates) return;

    // Validate photo
    if (_photoBytes == null || _photoMimeType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take or upload a photo of the issue.'),
          backgroundColor: AppColors.severityCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate form fields
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedBuilding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a campus building.'),
          backgroundColor: AppColors.severityCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final isManual = _isManualFloorBuilding(_selectedBuilding);
    if (!isManual && _selectedFloor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a floor for the building.'),
          backgroundColor: AppColors.severityCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (isManual && _manualFloorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the floor details for this building.'),
          backgroundColor: AppColors.severityCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Validate location details adheres to database constraints (2 - 255 chars)
    final locationValidation = LocationDetailsValidator.validate(
      _locationDetailsController.text,
      isRequired: true,
    );
    if (locationValidation != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locationValidation),
          backgroundColor: AppColors.severityCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to submit an issue report.'),
          backgroundColor: AppColors.severityCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Pre-submission duplicate check
    final signature = '${_selectedBuilding?.id}_${_selectedCategory.name}_${_titleController.text.trim().toLowerCase()}_${_descController.text.trim().toLowerCase()}_${_selectedFloor?.id}_${_manualFloorController.text.trim().toLowerCase()}_${_locationDetailsController.text.trim().toLowerCase()}';

    if (_duplicateCheckStale || _lastCheckedSignature != signature) {
      setState(() => _isCheckingDuplicates = true);

      try {
        final repo = ref.read(reportsRepositoryProvider);
        final dupResult = await repo.checkDuplicates(
          buildingId: _selectedBuilding!.id,
          category: _selectedCategory,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          floorId: !isManual ? _selectedFloor?.id : null,
          floorText: isManual ? _manualFloorController.text.trim() : null,
          locationDetails: _locationDetailsController.text.trim().isNotEmpty
              ? _locationDetailsController.text.trim()
              : null,
        );

        if (!mounted) return;
        setState(() {
          _isCheckingDuplicates = false;
          _duplicateResult = dupResult;
          _lastCheckedSignature = signature;
          _duplicateCheckStale = false;
        });

        if (dupResult.hasMatch) {
          _showDuplicateWarningModal(dupResult);
          return;
        } else if (dupResult.outcome == DuplicateOutcome.checkUnavailable) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Duplicate check is temporarily unavailable. Proceeding with report submission.'),
              backgroundColor: Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        debugPrint('Pre-submission duplicate check failed: $e');
        if (!mounted) return;
        setState(() => _isCheckingDuplicates = false);
      }
    } else if (_duplicateResult != null && _duplicateResult!.hasMatch) {
      _showDuplicateWarningModal(_duplicateResult!);
      return;
    }

    _executeSubmission();
  }

  /// Executes database record insertion, photo upload, and gamification refresh.
  void _executeSubmission() async {
    if (_isSubmitting) return;

    if (_photoBytes == null || _photoMimeType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take or upload a photo of the issue.'),
          backgroundColor: AppColors.severityCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Synchronously mark submitting to prevent rapid multi-tap race conditions
    setState(() => _isSubmitting = true);

    final isManual = _isManualFloorBuilding(_selectedBuilding);
    final draftId = const Uuid().v4();
    final suggestedDept = _aiAnalysis?.department ?? _getSuggestedDepartmentLabel(_selectedCategory);

    final draft = ReportSubmissionDraft(
      draftId: draftId,
      title: _titleController.text.trim(),
      category: _selectedCategory,
      severity: _selectedSeverity,
      buildingId: _selectedBuilding!.id,
      floorId: !isManual ? _selectedFloor?.id : null,
      floorText: isManual ? _manualFloorController.text.trim() : null,
      areaId: null, // Areas table is currently unseeded per PRD spec
      locationDetails: _locationDetailsController.text.trim(),
      description: _descController.text.trim(),
      suggestedDepartmentLabel: suggestedDept,
      latitude: _locationStatus == LocationCaptureStatus.attached ? _deviceLatitude : null,
      longitude: _locationStatus == LocationCaptureStatus.attached ? _deviceLongitude : null,
      photoBytes: _photoBytes!,
      photoMimeType: _photoMimeType!,
      photoFileName: _pickedFile?.name ?? 'photo.jpg',
    );

    try {
      final repo = ref.read(reportsRepositoryProvider);
      final createdReport = await repo.submitReport(draft: draft, userId: user.id);

      // Optimistically update providers
      ref.read(myReportsProvider.notifier).addReport(createdReport);

      // Refresh live EcoScore, points, achievements, and campus feed from Supabase
      await ref.read(ecoPointsProvider.notifier).refresh();
      ref.invalidate(campusReportsProvider);
      ref.invalidate(leaderboardProvider);
      ref.invalidate(achievementsProvider);
      ref.invalidate(dailyChallengesProvider);
      ref.invalidate(buildingSummariesProvider);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      _showSuccessReceiptDialog(createdReport, awardedPoints: 5);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final String errorMsg;
      if (e is ReportSubmissionException) {
        errorMsg = e.message;
      } else if (e.toString().contains('permission denied') ||
          e.toString().contains('42501')) {
        errorMsg = 'Database permission error: INSERT privilege missing on public.reports in Supabase.';
      } else if (e.toString().contains('23514') ||
          e.toString().contains('location_details') ||
          e.toString().contains('location_detials')) {
        errorMsg = 'Location details must be between 2 and 255 characters.';
      } else {
        errorMsg = 'Failed to submit report. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.severityCritical,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Displays the Duplicate Warning bottom sheet when a similar active issue is found.
  void _showDuplicateWarningModal(DuplicateCheckResult result) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFD97706),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'This issue may already be reported',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            result.outcome == DuplicateOutcome.likelyDuplicate
                                ? 'Likely duplicate issue detected'
                                : 'Possible matching report found',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'We found an existing report that looks similar. Review it before submitting a new one.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSecondary),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.38,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: result.candidates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final candidate = result.candidates[i];
                      return _buildCandidateCard(candidate, modalCtx);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(modalCtx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: const BorderSide(color: AppColors.borderLight),
                        ),
                        child: const Text(
                          'Edit My Report',
                          style: TextStyle(color: AppColors.inkPrimary, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(modalCtx).pop();
                          _executeSubmission();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text(
                          'Report Anyway',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCandidateCard(DuplicateCandidate candidate, BuildContext modalCtx) {
    Color statusBg;
    Color statusText;
    switch (candidate.status) {
      case ReportStatus.reported:
        statusBg = const Color(0xFFFEF3C7);
        statusText = const Color(0xFFB45309);
        break;
      case ReportStatus.assigned:
        statusBg = const Color(0xFFE0E7FF);
        statusText = const Color(0xFF4338CA);
        break;
      case ReportStatus.inProgress:
        statusBg = const Color(0xFFDBEAFE);
        statusText = const Color(0xFF1D4ED8);
        break;
      default:
        statusBg = const Color(0xFFF1F5F9);
        statusText = AppColors.inkSecondary;
    }

    final String floorInfo = candidate.floorName != null && candidate.floorName!.isNotEmpty
        ? ' · ${candidate.floorName}'
        : '';
    final String areaInfo = candidate.areaName != null && candidate.areaName!.isNotEmpty
        ? ' (${candidate.areaName})'
        : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  candidate.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  candidate.status.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  candidate.category.displayName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${candidate.buildingName}$floorInfo$areaInfo',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reported ${_formatRelativeTime(candidate.reportedAt)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(modalCtx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReportDetailScreen(
                        reportId: candidate.reportId,
                        initialReport: candidate.toReportModel(),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 12, color: Colors.white),
                label: const Text(
                  'View Existing Report',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }


  String _getSuggestedDepartmentLabel(IssueCategory category) {
    switch (category) {
      case IssueCategory.waste:
        return 'Sanitation & Grounds';
      case IssueCategory.water:
        return 'Plumbing & Facilities';
      case IssueCategory.electricity:
        return 'Electrical Maintenance';
      case IssueCategory.infrastructure:
        return 'Campus Infrastructure';
      case IssueCategory.greenery:
        return 'Horticulture & Landscape';
      case IssueCategory.cleanliness:
        return 'Housekeeping';
      case IssueCategory.other:
        return 'General Operations';
    }
  }

  void _showSuccessReceiptDialog(ReportModel report, {int awardedPoints = EcoScoringRules.reportSubmitted}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFD6F2E3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Report Submitted!',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tracking ID: ${report.id}',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FAF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFE9D2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, color: Color(0xFFD98327), size: 20),
                    const SizedBox(width: 6),
                    Text(
                      awardedPoints > 0
                          ? '+$awardedPoints EcoPoints Earned!'
                          : 'Report Recorded',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Initial status: ${report.status.displayName}\nAssigned to ${report.department ?? "Campus Facilities"}. Our team has been notified.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationPickerModal(List<CampusBuilding> buildings) {
    CampusBuilding? tempBuilding = _selectedBuilding ?? (buildings.isNotEmpty ? buildings.first : null);
    CampusFloor? tempFloor = _selectedFloor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isManual = _isManualFloorBuilding(tempBuilding);
          final floorsAsync = tempBuilding != null
              ? ref.watch(buildingFloorsProvider(tempBuilding!.id))
              : const AsyncValue<List<CampusFloor>>.data([]);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Select Location',
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Campus hierarchy: Building → Floor → Exact Details (PRD §7.6)',
                        style: AppTextStyles.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      // 1. Building Dropdown
                      Text('Building', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<CampusBuilding>(
                        value: tempBuilding,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: buildings
                            .map((b) => DropdownMenuItem(
                                  value: b,
                                  child: Text(b.name, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() {
                              tempBuilding = val;
                              tempFloor = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // 2. Floor Selection (Dropdown vs Manual Input)
                      if (!isManual) ...[
                        Text('Floor', style: AppTextStyles.labelMedium),
                        const SizedBox(height: 6),
                        floorsAsync.when(
                          data: (floors) {
                            if (floors.isNotEmpty && tempFloor == null) {
                              tempFloor = floors.first;
                            }
                            return DropdownButtonFormField<CampusFloor>(
                              value: tempFloor,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: floors
                                  .map((f) => DropdownMenuItem(
                                        value: f,
                                        child: Text(f.label),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                setModalState(() => tempFloor = val);
                              },
                            );
                          },
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          error: (err, _) => Text(
                            'Failed to load floors: $err',
                            style: const TextStyle(color: AppColors.severityCritical, fontSize: 12),
                          ),
                        ),
                      ] else ...[
                        Text('Floor (Manual Entry)', style: AppTextStyles.labelMedium),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _manualFloorController,
                          decoration: InputDecoration(
                            hintText: 'e.g. Ground Floor, Floor 2, Wing A',
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      // 3. Exact Location Details (Required)
                      Text('Exact Location / Room / Corridor', style: AppTextStyles.labelMedium),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _locationDetailsController,
                        maxLength: 255,
                        decoration: InputDecoration(
                          hintText: 'e.g. Room 204, East Entrance, Corridor',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (val) => LocationDetailsValidator.validate(val, isRequired: true),
                      ),
                      const SizedBox(height: 16),
                      // 4. Automatic GPS Location Indicator
                      Text('Automatic Coordinates', style: AppTextStyles.labelMedium),
                      _buildLocationStatusBadge(),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            final locError = LocationDetailsValidator.validate(
                              _locationDetailsController.text,
                              isRequired: true,
                            );
                            if (locError != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(locError),
                                  backgroundColor: AppColors.severityCritical,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _selectedBuilding = tempBuilding;
                              _selectedFloor = tempFloor;
                              _invalidateDuplicateCheck();
                            });
                            Navigator.of(sheetCtx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          child: const Text(
                            'Confirm Location',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buildingsAsync = ref.watch(campusBuildingsProvider);

    // Auto-select initial building when loaded if not yet set
    buildingsAsync.whenData((buildings) {
      if (_selectedBuilding == null && buildings.isNotEmpty) {
        _selectedBuilding = buildings.firstWhere(
          (b) => b.name == 'Engineering Block',
          orElse: () => buildings.first,
        );
      }
    });

    final String displayFloorText = _selectedBuilding != null && _isManualFloorBuilding(_selectedBuilding)
        ? (_manualFloorController.text.isNotEmpty ? _manualFloorController.text : 'Manual Floor')
        : (_selectedFloor?.label ?? 'Ground Floor');

    final String displayBuildingText = _selectedBuilding?.name ?? 'Select Building';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.inkPrimary),
            ),
          ),
        ),
        title: Text(
          'Report issue',
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Photo Viewfinder Card
              _buildPhotoCard(),

              if (_photoError != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.severityCritical, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _photoError!,
                          style: const TextStyle(color: AppColors.severityCritical, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_aiAnalysisError != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _aiAnalysisError!,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                        ),
                      ),
                      InkWell(
                        onTap: _runAiAnalysis,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 2. Mascot Status Row
              _buildMascotStatusRow(),

              const SizedBox(height: 16),

              // 2.5 AI Suggestions Card
              _buildAiSuggestionsCard(),

              // 3. Form Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF144D37).withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Issue Title & Editable Field
                    Text(
                      'Issue Title',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
                      onChanged: (val) {
                        setState(() {
                          _titleEditedByUser = true;
                          _duplicateCheckStale = true;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'e.g. Broken water pipe, overflowing bin',
                        filled: true,
                        fillColor: AppColors.surfaceSubtle,
                        suffixIcon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.inkSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Issue title is required';
                        if (val.trim().length < 3) return 'Must be at least 3 characters';
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Category Selector Chips
                    Text(
                      'Category',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: IssueCategory.values.map((cat) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildCategoryChip(cat),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Severity Segmented Selector
                    Text(
                      'Severity',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildSeverityOption(IssueSeverity.low, AppColors.severityLow)),
                          Expanded(child: _buildSeverityOption(IssueSeverity.medium, AppColors.severityMedium)),
                          Expanded(child: _buildSeverityOption(IssueSeverity.high, AppColors.severityHigh)),
                          Expanded(child: _buildSeverityOption(IssueSeverity.critical, AppColors.severityCritical)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Location Card (Building -> Floor -> Details)
                    Text(
                      'Campus Location',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    buildingsAsync.when(
                      data: (buildings) {
                        if (_selectedBuilding == null &&
                            widget.initialBuildingName != null &&
                            buildings.isNotEmpty) {
                          final match = buildings.where((b) {
                            final target = widget.initialBuildingName!.toLowerCase().trim();
                            final bName = b.name.toLowerCase().trim();
                            return bName == target || bName.contains(target) || target.contains(bName);
                          }).firstOrNull;
                          if (match != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && _selectedBuilding == null) {
                                setState(() => _selectedBuilding = match);
                              }
                            });
                          }
                        }
                        return InkWell(
                          onTap: () => _showLocationPickerModal(buildings),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD6F2E3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$displayBuildingText · $displayFloorText',
                                      style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _locationDetailsController.text.trim().isNotEmpty
                                          ? _locationDetailsController.text.trim()
                                          : 'Tap to change building or floor',
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.inkSecondary),
                            ],
                          ),
                        ),
                      );
                    },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (err, _) => Text(
                        'Failed to load buildings: $err',
                        style: const TextStyle(color: AppColors.severityCritical, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Specific Location Details',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _locationDetailsController,
                      maxLength: 255,
                      style: AppTextStyles.bodyMedium,
                      onChanged: (val) {
                        setState(() {
                          _invalidateDuplicateCheck();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'e.g. Room 204, East Entrance, West Corridor',
                        filled: true,
                        fillColor: AppColors.surfaceSubtle,
                        prefixIcon: const Icon(Icons.meeting_room_outlined, size: 20, color: AppColors.inkSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                      validator: (val) => LocationDetailsValidator.validate(val, isRequired: true),
                    ),
                    _buildLocationStatusBadge(),
                    const SizedBox(height: 18),

                    // Description Field
                    Text(
                      'Description',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      style: AppTextStyles.bodyMedium,
                      onChanged: (val) {
                        setState(() {
                          _descEditedByUser = true;
                          _duplicateCheckStale = true;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Describe what happened and any safety or hazard details...',
                        filled: true,
                        fillColor: AppColors.surfaceSubtle,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.borderLight),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Description is required';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Duplicate Check Result Card
              _buildDuplicateStatusCard(),

              // 5. Pre-submission "Check for duplicates" manual action
              OutlinedButton.icon(
                onPressed: (_isCheckingDuplicates || _isSubmitting)
                    ? null
                    : _runManualDuplicateCheck,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  side: BorderSide(
                    color: _duplicateResult != null && !_duplicateCheckStale
                        ? AppColors.primary
                        : AppColors.borderLight,
                  ),
                ),
                icon: const Icon(Icons.search_rounded, size: 18, color: AppColors.primary),
                label: Text(
                  _duplicateResult != null && !_duplicateCheckStale
                      ? 'Re-check duplicates'
                      : 'Check for similar active issues',
                  style: const TextStyle(
                    color: AppColors.inkPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 6. Submit Button with "+30 EcoPoints" badge
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isSubmitting
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Uploading & Submitting...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Submit report',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '+${EcoScoringRules.reportSubmitted} EcoPoints',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard() {
    final bool hasPhoto = _photoBytes != null;

    return Container(
      height: 230,
      width: double.infinity,
      decoration: BoxDecoration(
        color: hasPhoto ? Colors.black : const Color(0xFF9FB6C4),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo display or Camera Action Area
            if (hasPhoto) ...[
              Image.memory(
                _photoBytes!,
                fit: BoxFit.cover,
                cacheWidth: 800,
                cacheHeight: 600,
                width: double.infinity,
                height: double.infinity,
              ),
              // Gradient scrim
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Placeholder with camera & gallery buttons
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Snap or upload campus issue photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        shadows: [
                          Shadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 16),
                          label: const Text('Take Photo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.inkPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 16),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.inkPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Viewfinder Corner Brackets
            Positioned(
              top: 20,
              left: 20,
              child: _buildCornerBracket(isTop: true, isLeft: true),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              child: _buildCornerBracket(isTop: false, isLeft: true),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: _buildCornerBracket(isTop: false, isLeft: false),
            ),

            // Top Status Badge
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF14241E).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: hasPhoto ? const Color(0xFF2ECC71) : const Color(0xFFF39C12),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasPhoto
                          ? '${(_photoBytes!.length / 1024).toStringAsFixed(0)} KB · Ready'
                          : 'Photo Required',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Retake / Replace / Remove controls (when photo exists)
            if (hasPhoto) ...[
              // Left: Analyze with AI button
              Positioned(
                bottom: 16,
                left: 16,
                child: InkWell(
                  onTap: _isAnalyzing ? null : _runAiAnalysis,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _aiAnalysis != null ? const Color(0xFF144D37) : AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isAnalyzing) ...[
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Analyzing...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ] else ...[
                          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _aiAnalysis != null ? 'Re-analyze' : 'Analyze with AI',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Right: Retake & Clear buttons
              Positioned(
                bottom: 16,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _clearPhoto,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.severityCritical),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _pickImage(ImageSource.camera),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded, size: 16, color: AppColors.inkPrimary),
                            SizedBox(width: 4),
                            Text(
                              'Retake',
                              style: TextStyle(
                                color: AppColors.inkPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCornerBracket({required bool isTop, required bool isLeft}) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _BracketPainter(isTop: isTop, isLeft: isLeft),
      ),
    );
  }

  Widget _buildMascotStatusRow() {
    String title;
    String subtitle;
    if (_isAnalyzing) {
      title = 'AI is analyzing your photo...';
      subtitle = 'Detecting issue category, severity & campus department';
    } else if (_aiAnalysis != null) {
      title = _aiAnalysis!.needsReview ? 'AI suggestions need review' : 'AI suggestions ready!';
      subtitle = 'Editable suggestions added below. Review and adjust anytime.';
    } else if (_photoBytes != null) {
      title = 'Photo attached & ready';
      subtitle = 'Tap "Analyze with AI" for automatic issue understanding';
    } else {
      title = 'Manual reporting active';
      subtitle = 'Snap a photo to enable AI analysis and duplicate detection';
    }

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFFD6F2E3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SprigMascot(size: 32, animated: _isAnalyzing),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiSuggestionsCard() {
    if (_isAnalyzing) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Issue Understanding in progress...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Analyzing photo for category, severity, and responsible department',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_aiAnalysis == null) return const SizedBox.shrink();

    final analysis = _aiAnalysis!;
    Color confBg;
    Color confText;
    String confLabel;

    if (analysis.needsReview) {
      confBg = const Color(0xFFFEF3C7);
      confText = const Color(0xFFB45309);
      confLabel = 'Review Recommended';
    } else {
      switch (analysis.confidence) {
        case 'high':
          confBg = const Color(0xFFDCFCE7);
          confText = const Color(0xFF15803D);
          confLabel = 'High Confidence';
          break;
        case 'low':
          confBg = const Color(0xFFFEE2E2);
          confText = const Color(0xFFB91C1C);
          confLabel = 'Low Confidence';
          break;
        default:
          confBg = const Color(0xFFE0E7FF);
          confText = const Color(0xFF4338CA);
          confLabel = 'Medium Confidence';
      }
    }

    final hasUserEdits = _titleEditedByUser || _descEditedByUser || _categoryEditedByUser || _severityEditedByUser;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD1FAE5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF144D37).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD6F2E3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Suggestions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.inkPrimary,
                      ),
                    ),
                    if (analysis.department != null)
                      Text(
                        'Assigned to: ${analysis.department}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: confBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  confLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: confText,
                  ),
                ),
              ),
            ],
          ),
          if (analysis.reasoningSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      analysis.reasoningSummary,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAiSuggestionTag(
                label: 'Title: ${analysis.issueTitle}',
                isOverridden: _titleEditedByUser && _titleController.text.trim() != analysis.issueTitle,
              ),
              _buildAiSuggestionTag(
                label: 'Cat: ${analysis.category.displayName}',
                isOverridden: _categoryEditedByUser && _selectedCategory != analysis.category,
              ),
              _buildAiSuggestionTag(
                label: 'Sev: ${analysis.severity.displayName}',
                isOverridden: _severityEditedByUser && _selectedSeverity != analysis.severity,
              ),
              if (analysis.department != null)
                _buildAiSuggestionTag(
                  label: 'Dept: ${analysis.department}',
                  isOverridden: false,
                ),
            ],
          ),
          if (hasUserEdits) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _titleController.text = analysis.issueTitle;
                    _descController.text = analysis.issueDescription;
                    _selectedCategory = analysis.category;
                    _selectedSeverity = analysis.severity;
                    _titleEditedByUser = false;
                    _descEditedByUser = false;
                    _categoryEditedByUser = false;
                    _severityEditedByUser = false;
                    _invalidateDuplicateCheck();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Re-applied original AI suggestions to form.'),
                      backgroundColor: AppColors.primary,
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.restore_rounded, size: 16, color: AppColors.primary),
                label: const Text(
                  'Restore AI suggestions',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiSuggestionTag({required String label, required bool isOverridden}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOverridden ? const Color(0xFFF1F5F9) : const Color(0xFFEAF5EE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOverridden ? const Color(0xFFCBD5E1) : const Color(0xFFA7E0BD),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverridden ? Icons.edit_note_rounded : Icons.check_circle_outline_rounded,
            size: 13,
            color: isOverridden ? AppColors.inkSecondary : const Color(0xFF15803D),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isOverridden ? AppColors.inkSecondary : const Color(0xFF144D37),
              decoration: isOverridden ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateStatusCard() {
    if (_isCheckingDuplicates) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Checking for similar active issues on campus...',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inkPrimary),
              ),
            ),
          ],
        ),
      );
    }

    if (_duplicateResult == null || _duplicateCheckStale) {
      return const SizedBox.shrink();
    }

    final res = _duplicateResult!;
    if (res.hasMatch) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    res.outcome == DuplicateOutcome.likelyDuplicate
                        ? 'Likely duplicate issue found (${res.candidates.length})'
                        : 'Possible match found (${res.candidates.length})',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                  ),
                  Text(
                    res.explanation,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _showDuplicateWarningModal(res),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Review',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
              ),
            ),
          ],
        ),
      );
    } else if (res.outcome == DuplicateOutcome.noMatch) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No similar active report was found in ${_selectedBuilding?.name ?? "this building"}. Ready to submit.',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
              ),
            ),
          ],
        ),
      );
    } else if (res.outcome == DuplicateOutcome.checkUnavailable) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Duplicate checking temporarily unavailable. You can proceed with submission.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildCategoryChip(IssueCategory cat) {
    final bool isSelected = _selectedCategory == cat;
    final bool isAiSuggested = _aiAnalysis != null && _aiAnalysis!.category == cat;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedCategory = cat;
        _categoryEditedByUser = true;
        _invalidateDuplicateCheck();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(20),
          border: isAiSuggested && !isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAiSuggested) ...[
              Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              cat.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.inkPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityOption(IssueSeverity severity, Color dotColor) {
    final bool isSelected = _selectedSeverity == severity;
    final bool isAiSuggested = _aiAnalysis != null && _aiAnalysis!.severity == severity;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedSeverity = severity;
        _severityEditedByUser = true;
        _duplicateCheckStale = true;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: isAiSuggested && !isSelected
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.2)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              severity.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.inkPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;

  _BracketPainter({required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else if (!isTop && !isLeft) {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else if (isTop && !isLeft) {
      path.moveTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

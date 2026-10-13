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
import '../domain/campus_location_models.dart';
import '../domain/report_model.dart';
import '../../rewards/data/eco_points_provider.dart';
import '../../rewards/data/achievements_provider.dart';
import '../../rewards/data/challenges_provider.dart';
import '../../rewards/domain/eco_points_model.dart';

const int kMaxPhotoSizeBytes = 8 * 1024 * 1024; // 8 MB limit

enum LocationCaptureStatus { getting, attached, unavailable }

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

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

  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Overflowing waste bin');
    _descController = TextEditingController(
      text: 'Recycling bin overflowing with food containers and cups spilling onto walkway.',
    );
    _locationDetailsController = TextEditingController(text: 'Near East Patio entrance');
    _manualFloorController = TextEditingController();
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
    });
  }

  void _submitReport() async {
    if (_isSubmitting) return;

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

    final draftId = const Uuid().v4();
    final suggestedDept = _getSuggestedDepartmentLabel(_selectedCategory);

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

    setState(() => _isSubmitting = true);

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

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      _showSuccessReceiptDialog(createdReport, awardedPoints: 5);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final errorMsg = e.toString().contains('permission denied') ||
              e.toString().contains('42501')
          ? 'Database permission error: INSERT privilege missing on public.reports in Supabase.'
          : 'Failed to submit report: $e';

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
                        decoration: InputDecoration(
                          hintText: 'e.g. Room 204, East Entrance, Corridor',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
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
                            setState(() {
                              _selectedBuilding = tempBuilding;
                              _selectedFloor = tempFloor;
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
    final String displayDetailsText = _locationDetailsController.text.isNotEmpty
        ? _locationDetailsController.text
        : 'Exact room / area';

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

              const SizedBox(height: 16),

              // 2. Mascot Status Row
              _buildMascotStatusRow(),

              const SizedBox(height: 16),

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
                      data: (buildings) => InkWell(
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
                                      displayDetailsText,
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.inkSecondary),
                            ],
                          ),
                        ),
                      ),
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

              const SizedBox(height: 24),

              // Submit Button with "+30 EcoPoints" badge
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
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFFD6F2E3),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: SprigMascot(size: 32, animated: false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manual reporting active',
                style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              Text(
                'Review and verify campus location before submission',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(IssueCategory cat) {
    final bool isSelected = _selectedCategory == cat;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = cat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          cat.displayName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.inkPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityOption(IssueSeverity severity, Color dotColor) {
    final bool isSelected = _selectedSeverity == severity;
    return GestureDetector(
      onTap: () => setState(() => _selectedSeverity = severity),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
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

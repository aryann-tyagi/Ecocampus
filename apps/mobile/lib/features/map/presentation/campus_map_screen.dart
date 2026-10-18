import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_bottom_nav.dart';
import '../../report/presentation/report_issue_screen.dart';
import '../../reports_tracking/presentation/my_reports_screen.dart';
import '../data/campus_map_provider.dart';
import '../domain/campus_building_summary_model.dart';

/// EcoCampus Visual Design System Colors for Campus Map.
class _MapColors {
  static const Color forestGreen = Color(0xFF1B4332);
  static const Color footprintFill = Color(0xFFCBE4D2);
  static const Color footprintOutline = Color(0xFF749F82);
  static const Color alertRed = Color(0xFFD32F2F);
  static const Color alertRedBg = Color(0xFFFDECEA);
  static const Color alertRedBorder = Color(0xFFF5C6CB);
  static const Color canvasBg = Color(0xFFF6F8F5);
  static const Color pathColor = Color(0xFFE2EAE4);
  static const Color lawnFill = Color(0xFFEBF3ED);
  static const Color treeFill = Color(0xFFA3C7B0);
  static const Color neutralText = Color(0xFF5F7166);
  static const Color neutralBorder = Color(0xFFE2EBE5);
  static const Color statBg = Color(0xFFF4F6F4);
}

/// Zone definitions matching the 3 authentic campus areas.
class _ZoneDefinition {
  final String code;
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<String> canonicalNames;

  const _ZoneDefinition({
    required this.code,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.canonicalNames,
  });
}

const List<_ZoneDefinition> _kCampusZones = [
  _ZoneDefinition(
    code: 'G1',
    title: 'Hostel & Parking Zone',
    icon: Icons.local_parking_rounded,
    accentColor: Color(0xFF2E86DE),
    canonicalNames: [
      'bus parking',
      'boys hostel',
      'girls hostel',
      'hostel mess',
      'hostel ground',
    ],
  ),
  _ZoneDefinition(
    code: 'G2',
    title: 'Café & Library Zone',
    icon: Icons.local_cafe_rounded,
    accentColor: Color(0xFFD98327),
    canonicalNames: [
      'royals cafe',
      'cafeteria',
      'hotel management block',
      'library',
    ],
  ),
  _ZoneDefinition(
    code: 'G3',
    title: 'Academic & Sports Zone',
    icon: Icons.school_rounded,
    accentColor: Color(0xFF1B4332),
    canonicalNames: [
      'engineering block',
      'new engineering block',
      'old law block',
      'law library',
      'sports complex',
    ],
  ),
];

/// Layout metadata for drawing subtle zone labels on the canvas.
class _ZoneHeaderLayout {
  final String code;
  final String title;
  final IconData icon;
  final Color accentColor;
  final Offset position;
  final double width;

  const _ZoneHeaderLayout({
    required this.code,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.position,
    required this.width,
  });
}

/// Represents a non-overlapping, comfortably positioned building marker
/// on the scrollable campus schematic canvas.
class _PositionedMarker {
  final CampusBuildingSummary building;
  final Offset anchorPos;
  final Offset markerPos;
  final double width;
  final double height;
  final String zoneCode;

  const _PositionedMarker({
    required this.building,
    required this.anchorPos,
    required this.markerPos,
    this.width = 124.0,
    this.height = 36.0,
    required this.zoneCode,
  });
}

/// Category item helper for dynamic ordering in the bottom details sheet.
class _CategoryItem {
  final String label;
  final int count;
  final IconData icon;
  final int priority;

  const _CategoryItem({
    required this.label,
    required this.count,
    required this.icon,
    required this.priority,
  });
}

class CampusMapScreen extends ConsumerStatefulWidget {
  final bool isActive;
  final bool enableContinuousAnimations;

  const CampusMapScreen({
    super.key,
    this.isActive = true,
    this.enableContinuousAnimations = true,
  });

  @override
  ConsumerState<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends ConsumerState<CampusMapScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TransformationController _transformController =
      TransformationController();

  String _searchQuery = '';
  CampusMapFilter _activeFilter = CampusMapFilter.all;

  // Explicit building selection & animation origin tracking
  String? _previousBuildingId;
  Offset? _previousBuildingPos;
  String? _selectedBuildingId;
  Offset? _selectedBuildingPos;
  bool _isDetailsDismissed = false;

  // Layer toggle state
  bool _showBuildings = true;
  bool _showWalkways = true;
  bool _showLandscaping = true;

  late final AnimationController _ambientController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _pathFlowAnimation;

  // Building-to-building travel transition animation
  late final AnimationController _transitionAnimationController;
  late final Animation<double> _transitionAnimation;

  late final AnimationController _panAnimationController;
  Animation<Matrix4>? _panAnimation;

  double _lastViewportWidth = 360.0;
  double _lastViewportHeight = 600.0;
  double _currentCanvasHeight = 1360.0;

  List<_PositionedMarker> _currentPositionedMarkers = [];
  List<_ZoneHeaderLayout> _currentZoneHeaders = [];

  @override
  void initState() {
    super.initState();

    // Ambient flow animation along spine
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _pathFlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOut),
    );

    // Transition animation connecting previously selected to newly selected building
    _transitionAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _transitionAnimation = CurvedAnimation(
      parent: _transitionAnimationController,
      curve: Curves.easeInOutCubic,
    );

    // Pan controller for smooth viewport center transitions
    _panAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    if (widget.isActive && widget.enableContinuousAnimations) {
      _ambientController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CampusMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        ref.read(buildingSummariesProvider.notifier).refresh();
        if (widget.enableContinuousAnimations && !_ambientController.isAnimating) {
          _ambientController.repeat();
        }
      } else {
        if (_ambientController.isAnimating) {
          _ambientController.stop();
        }
      }
    }
    if (widget.enableContinuousAnimations != oldWidget.enableContinuousAnimations) {
      if (widget.enableContinuousAnimations && widget.isActive && !_ambientController.isAnimating) {
        _ambientController.repeat();
      } else if ((!widget.enableContinuousAnimations || !widget.isActive) && _ambientController.isAnimating) {
        _ambientController.stop();
      }
    }
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _transitionAnimationController.dispose();
    _panAnimationController.dispose();
    _searchController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Offset? _getBuildingCanvasPosition(String buildingId) {
    for (final m in _currentPositionedMarkers) {
      if (m.building.buildingId == buildingId) {
        return m.markerPos;
      }
    }
    return null;
  }

  /// Selects a building, updating animation origin to the previous building footprint
  /// and destination to the newly selected building footprint.
  void _selectBuilding(CampusBuildingSummary building) {
    if (_selectedBuildingId == building.buildingId) {
      if (_isDetailsDismissed) {
        setState(() => _isDetailsDismissed = false);
      }
      return;
    }

    final Offset? oldPos = _selectedBuildingId != null
        ? (_getBuildingCanvasPosition(_selectedBuildingId!) ?? _selectedBuildingPos)
        : null;
    final Offset? newPos = _getBuildingCanvasPosition(building.buildingId);

    setState(() {
      _previousBuildingId = _selectedBuildingId;
      _previousBuildingPos = oldPos;
      _selectedBuildingId = building.buildingId;
      _selectedBuildingPos = newPos;
      _isDetailsDismissed = false;
    });

    _animateToBuilding(building);

    // If transitioning between two different buildings, run transition animation
    if (oldPos != null && newPos != null && oldPos != newPos && widget.enableContinuousAnimations) {
      _transitionAnimationController.forward(from: 0.0);
    } else {
      _transitionAnimationController.value = 1.0;
    }
  }

  /// Smoothly animates the transformation controller to center on a building marker.
  void _animateToBuilding(CampusBuildingSummary building) {
    if (_currentPositionedMarkers.isEmpty) return;

    final marker = _currentPositionedMarkers.firstWhere(
      (m) => m.building.buildingId == building.buildingId,
      orElse: () => _currentPositionedMarkers.first,
    );

    final double vpWidth = _lastViewportWidth;
    final double vpHeight = _lastViewportHeight;
    if (vpHeight <= 0) return;

    final double targetY = marker.markerPos.dy;
    final double targetX = marker.markerPos.dx;
    const double desiredScale = 1.0;

    final double desiredScreenY = vpHeight * 0.28;
    final double desiredScreenX = vpWidth / 2.0;

    double targetDy = desiredScreenY - (targetY * desiredScale);
    double targetDx = desiredScreenX - (targetX * desiredScale);

    final double minDy = vpHeight - (_currentCanvasHeight * desiredScale);
    if (minDy < 0) {
      targetDy = targetDy.clamp(minDy, 10.0);
    } else {
      targetDy = 0.0;
    }
    targetDx = targetDx.clamp(-30.0, 30.0);

    final Matrix4 endMatrix = Matrix4.identity()
      ..translate(targetDx, targetDy)
      ..scale(desiredScale);

    _panAnimationController.reset();
    final Matrix4 startMatrix = _transformController.value.clone();
    _panAnimation = Matrix4Tween(begin: startMatrix, end: endMatrix).animate(
      CurvedAnimation(parent: _panAnimationController, curve: Curves.easeInOutCubic),
    );

    _panAnimation!.addListener(() {
      _transformController.value = _panAnimation!.value;
    });

    _panAnimationController.forward();
  }

  /// Resets map view to default starting position at top North Gateway.
  void _resetView() {
    final Matrix4 current = _transformController.value.clone();
    final Matrix4 target = Matrix4.identity();

    _panAnimationController.reset();
    _panAnimation = Matrix4Tween(begin: current, end: target).animate(
      CurvedAnimation(parent: _panAnimationController, curve: Curves.easeInOutCubic),
    );
    _panAnimation!.addListener(() {
      _transformController.value = _panAnimation!.value;
    });
    _panAnimationController.forward();
  }

  /// Centers the map on the selected building if present, or first campus building.
  void _locateOrRecenter(CampusBuildingSummary? selected) {
    if (selected != null) {
      _animateToBuilding(selected);
    } else if (_currentPositionedMarkers.isNotEmpty) {
      _animateToBuilding(_currentPositionedMarkers.first.building);
    } else {
      _resetView();
    }
  }

  void _showLayersMenu(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.layers_outlined, size: 20, color: _MapColors.forestGreen),
                  SizedBox(width: 8),
                  Text(
                    'Map Layers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.inkPrimary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Buildings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Footprints and building identifiers', style: TextStyle(fontSize: 12)),
                    value: _showBuildings,
                    activeColor: _MapColors.forestGreen,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => _showBuildings = val);
                        setState(() => _showBuildings = val);
                      }
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Walkways', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Paved pedestrian walkways and paths', style: TextStyle(fontSize: 12)),
                    value: _showWalkways,
                    activeColor: _MapColors.forestGreen,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => _showWalkways = val);
                        setState(() => _showWalkways = val);
                      }
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Landscaping', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Zone lawns, trees, and bioswales', style: TextStyle(fontSize: 12)),
                    value: _showLandscaping,
                    activeColor: _MapColors.forestGreen,
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => _showLandscaping = val);
                        setState(() => _showLandscaping = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done', style: TextStyle(color: _MapColors.forestGreen, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final bool accessibleNavigation =
        MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    final bool reduceMotion = disableAnimations ||
        accessibleNavigation ||
        !widget.enableContinuousAnimations ||
        !widget.isActive;

    if (reduceMotion && _ambientController.isAnimating) {
      _ambientController.stop();
    } else if (!reduceMotion && !_ambientController.isAnimating) {
      _ambientController.repeat();
    }

    final summariesAsync = ref.watch(buildingSummariesProvider);

    // Bottom navigation height accounting for MainNavigationShell's Scaffold(extendBody: true).
    // When hosted inside MainNavigationShell, MediaQuery.paddingOf(context).bottom already includes
    // the layout height of CustomBottomNavBar.
    final double scaffoldBottomPadding = MediaQuery.paddingOf(context).bottom;
    final double hardwareBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final double navBarHeight = scaffoldBottomPadding > hardwareBottomInset
        ? scaffoldBottomPadding
        : CustomBottomNavBar.totalHeight(context);

    return Scaffold(
      backgroundColor: _MapColors.canvasBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Fixed Header with Dynamic Campus Summary Metrics
            _buildHeader(summariesAsync),

            // 2. Fixed Search Bar & Dynamic Filter Chips
            _buildSearchAndFilters(summariesAsync),

            // 3. Map Viewport Occupying All Remaining Screen Space
            Expanded(
              child: summariesAsync.when(
                loading: () => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: _MapColors.forestGreen),
                      SizedBox(height: 12),
                      Text(
                        'Loading campus buildings...',
                        style: TextStyle(
                          color: AppColors.inkSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                error: (error, _) => _buildErrorState(),
                data: (allBuildings) {
                  if (allBuildings.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Apply search query and active filter
                  final filteredBuildings = allBuildings.where((b) {
                    final matchesQuery = _searchQuery.isEmpty ||
                        b.buildingName
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase());
                    if (!matchesQuery) return false;

                    switch (_activeFilter) {
                      case CampusMapFilter.all:
                        return true;
                      case CampusMapFilter.hasActive:
                        return b.activeReports > 0;
                      case CampusMapFilter.noIssues:
                        return b.activeReports == 0;
                    }
                  }).toList();

                  // Select active building safely without jump
                  CampusBuildingSummary? selectedBuilding;
                  if (filteredBuildings.isNotEmpty) {
                    selectedBuilding = filteredBuildings.firstWhere(
                      (b) => b.buildingId == _selectedBuildingId,
                      orElse: () {
                        final first = filteredBuildings.first;
                        _selectedBuildingId = first.buildingId;
                        return first;
                      },
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      _lastViewportWidth = constraints.maxWidth;
                      _lastViewportHeight = constraints.maxHeight - navBarHeight;

                      final bool isDetailsShowing = selectedBuilding != null &&
                          !_isDetailsDismissed &&
                          filteredBuildings.isNotEmpty;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Interactive Scrollable Map Canvas
                          // Viewport fills all available space directly above bottom navigation
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            bottom: navBarHeight,
                            child: _buildScrollableCanvas(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
                                maxHeight: constraints.maxHeight - navBarHeight,
                              ),
                              allBuildings: allBuildings,
                              filteredBuildings: filteredBuildings,
                              selectedBuilding: selectedBuilding,
                            ),
                          ),

                          // Overlay: Campus Schematic Chip (Upper-Left)
                          Positioned(
                            top: 10,
                            left: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _MapColors.neutralBorder,
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.explore_outlined,
                                    size: 13,
                                    color: _MapColors.forestGreen,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Campus Schematic',
                                    style: TextStyle(
                                      color: _MapColors.neutralText,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),



                          // Overlay: Map Layers Button (Upper-Right)
                          Positioned(
                            top: 10,
                            right: 14,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _MapColors.neutralBorder,
                                  width: 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.layers_outlined,
                                  size: 18,
                                  color: _MapColors.forestGreen,
                                ),
                                tooltip: 'Map Layers',
                                onPressed: () => _showLayersMenu(context),
                              ),
                            ),
                          ),

                          // Empty search overlay
                          if (filteredBuildings.isEmpty)
                            Center(
                              child: _buildNoMatchesOverlay(),
                            ),

                          // Lower-Right Floating Pill: Locate & Navigation Arrow
                          // Pinned cleanly above the bottom navigation or above details sheet
                          Positioned(
                            right: 14,
                            bottom: isDetailsShowing
                                ? (navBarHeight + 8.0 + 236)
                                : (navBarHeight + 14),
                            child: _buildFloatingControls(selectedBuilding),
                          ),

                          // Docked Building Details Bottom Sheet
                          // Positioned directly above the bottom navigation with a small, balanced gap
                          if (isDetailsShowing)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: navBarHeight + 8.0,
                              child: _buildDockedBuildingDetailsSheet(
                                selectedBuilding,
                                key: ValueKey(selectedBuilding.buildingId),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }



  // ---------------------------------------------------------------------------
  // Top Header: Title & Dynamic Issue Summary
  // ---------------------------------------------------------------------------
  Widget _buildHeader(AsyncValue<List<CampusBuildingSummary>> summariesAsync) {
    final buildings = summariesAsync.value ?? const [];
    final int totalActive =
        buildings.fold<int>(0, (sum, b) => sum + b.activeReports);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campus Map',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: _MapColors.forestGreen,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  buildings.isEmpty
                      ? 'Monitoring campus infrastructure'
                      : (totalActive == 0
                          ? 'All ${buildings.length} buildings operating nominally'
                          : '$totalActive active issue${totalActive == 1 ? '' : 's'} across ${buildings.length} buildings'),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: totalActive > 0
                        ? _MapColors.alertRed
                        : const Color(0xFF2C6B4F),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
            decoration: BoxDecoration(
              color: _MapColors.forestGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _MapColors.forestGreen.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, _) {
                    return Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1EA05A).withValues(
                          alpha: 0.6 + (_pulseAnimation.value * 0.4),
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 5),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _MapColors.forestGreen,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search Bar & Filter Row
  // ---------------------------------------------------------------------------
  Widget _buildSearchAndFilters(
      AsyncValue<List<CampusBuildingSummary>> summariesAsync) {
    final buildings = summariesAsync.value ?? const [];
    final activeBuildingsCount =
        buildings.where((b) => b.activeReports > 0).length;
    final cleanBuildingsCount =
        buildings.where((b) => b.activeReports == 0).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: _MapColors.neutralBorder,
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _MapColors.forestGreen.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: _MapColors.neutralText,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                        _isDetailsDismissed = false;
                      });

                      if (val.trim().isNotEmpty && buildings.isNotEmpty) {
                        final matches = buildings.where((b) => b.buildingName
                            .toLowerCase()
                            .contains(val.trim().toLowerCase())).toList();
                        if (matches.isNotEmpty) {
                          _selectBuilding(matches.first);
                        }
                      }
                    },
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.inkPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search campus buildings...',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: _MapColors.neutralText.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      color: _MapColors.neutralText,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildFilterChip(
                  filter: CampusMapFilter.all,
                  label: 'All',
                  count: buildings.length,
                  isAlert: false,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  filter: CampusMapFilter.hasActive,
                  label: 'With Issues',
                  count: activeBuildingsCount,
                  isAlert: true,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  filter: CampusMapFilter.noIssues,
                  label: 'No Issues',
                  count: cleanBuildingsCount,
                  isAlert: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required CampusMapFilter filter,
    required String label,
    required int count,
    required bool isAlert,
  }) {
    final bool isSelected = _activeFilter == filter;

    Color bgColor;
    Color borderColor;
    Color textColor;
    Color badgeBg;
    Color badgeTextColor;

    if (isAlert) {
      bgColor = isSelected ? _MapColors.alertRedBg : Colors.white;
      borderColor = isSelected ? _MapColors.alertRed : _MapColors.alertRedBorder;
      textColor = isSelected ? _MapColors.alertRed : AppColors.inkPrimary;
      badgeBg = isSelected ? Colors.white : _MapColors.alertRedBg;
      badgeTextColor = _MapColors.alertRed;
    } else {
      bgColor = isSelected ? const Color(0xFFEAF4EE) : Colors.white;
      borderColor = isSelected ? _MapColors.forestGreen : _MapColors.neutralBorder;
      textColor = isSelected ? _MapColors.forestGreen : AppColors.inkPrimary;
      badgeBg = isSelected
          ? _MapColors.forestGreen.withValues(alpha: 0.12)
          : const Color(0xFFF0F4F1);
      badgeTextColor = isSelected ? _MapColors.forestGreen : _MapColors.neutralText;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = isSelected ? CampusMapFilter.all : filter;
          _isDetailsDismissed = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: badgeTextColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Scrollable Campus Canvas: Three Distinct Zones
  // ---------------------------------------------------------------------------
  Widget _buildScrollableCanvas({
    required BoxConstraints constraints,
    required List<CampusBuildingSummary> allBuildings,
    required List<CampusBuildingSummary> filteredBuildings,
    required CampusBuildingSummary? selectedBuilding,
  }) {
    final double canvasWidth = constraints.maxWidth;

    final layoutResult = _layoutCampusThreeZones(
      canvasWidth: canvasWidth,
      buildings: allBuildings,
    );

    _currentPositionedMarkers = layoutResult.markers;
    _currentZoneHeaders = layoutResult.headers;
    _currentCanvasHeight = layoutResult.totalHeight;

    final Set<String> visibleBuildingIds =
        filteredBuildings.map((b) => b.buildingId).toSet();

    return InteractiveViewer(
      transformationController: _transformController,
      minScale: 0.75,
      maxScale: 1.6,
      boundaryMargin: EdgeInsets.zero,
      constrained: false,
      child: SizedBox(
        width: canvasWidth,
        height: _currentCanvasHeight,
        child: Stack(
          children: [
            // 1. Campus Grounds, Zones, Landscape & Paved Walkways Painter
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(canvasWidth, _currentCanvasHeight),
                  painter: _CampusSchematicMapPainter(
                    repaint: Listenable.merge([
                      _ambientController,
                      _transitionAnimationController,
                    ]),
                    flowProgress: _pathFlowAnimation,
                    transitionProgress: _transitionAnimation,
                    previousBuildingId: _previousBuildingId,
                    previousBuildingPos: _previousBuildingPos,
                    selectedBuildingPos: _selectedBuildingPos,
                    positionedMarkers: _currentPositionedMarkers,
                    zoneHeaders: _currentZoneHeaders,
                    showBuildings: _showBuildings,
                    showWalkways: _showWalkways,
                    showLandscaping: _showLandscaping,
                    selectedBuildingId: selectedBuilding?.buildingId,
                  ),
                ),
              ),
            ),

            // 2. Zone Header Labels across Canvas
            ..._buildZoneHeaderWidgets(_currentZoneHeaders),

            // 3. Single Clean Building Markers & Labels (No underlying duplicate boxes)
            if (_showBuildings)
              ..._buildBuildingMarkers(
                positionedMarkers: _currentPositionedMarkers,
                visibleBuildingIds: visibleBuildingIds,
                selected: selectedBuilding,
              ),
          ],
        ),
      ),
    );
  }

  /// Places buildings into G1, G2, G3 zones with guaranteed non-overlapping positions.
  _CampusLayoutResult _layoutCampusThreeZones({
    required double canvasWidth,
    required List<CampusBuildingSummary> buildings,
  }) {
    if (buildings.isEmpty) {
      return const _CampusLayoutResult(
        markers: [],
        headers: [],
        totalHeight: 1300.0,
      );
    }

    final List<List<CampusBuildingSummary>> zoneBuckets = [[], [], []];

    for (int i = 0; i < buildings.length; i++) {
      final b = buildings[i];
      final zoneIdx = _determineZoneIndex(b, i, buildings.length);
      zoneBuckets[zoneIdx].add(b);
    }

    final double markerWidth =
        math.min(124.0, math.max(104.0, (canvasWidth - 40.0) / 2.3));
    const double markerHeight = 36.0;
    final double halfW = markerWidth / 2.0;

    const double minX = 14.0;
    final double maxX = canvasWidth - 14.0;

    // Two staggered columns: West Column and East Column
    final double leftX = (minX + halfW + 4.0).clamp(minX + halfW, maxX - halfW);
    final double rightX = (maxX - halfW - 4.0).clamp(minX + halfW, maxX - halfW);

    final List<_PositionedMarker> allMarkers = [];
    final List<_ZoneHeaderLayout> allHeaders = [];

    double currentCursorY = 36.0;

    for (int z = 0; z < 3; z++) {
      final zoneDef = _kCampusZones[z];
      final zoneBuildings = zoneBuckets[z];

      final double headerY = currentCursorY;
      allHeaders.add(
        _ZoneHeaderLayout(
          code: zoneDef.code,
          title: zoneDef.title,
          icon: zoneDef.icon,
          accentColor: zoneDef.accentColor,
          position: Offset(canvasWidth * 0.50, headerY),
          width: canvasWidth,
        ),
      );

      currentCursorY += 50.0;

      const double rowStepY = 74.0;

      for (int bIdx = 0; bIdx < zoneBuildings.length; bIdx++) {
        final building = zoneBuildings[bIdx];
        final bool isLeft = (bIdx % 2 == 0);
        final double targetX = isLeft ? leftX : rightX;
        final double targetY = currentCursorY + (bIdx * rowStepY);

        allMarkers.add(
          _PositionedMarker(
            building: building,
            anchorPos: Offset(targetX, targetY),
            markerPos: Offset(targetX, targetY),
            width: markerWidth,
            height: markerHeight,
            zoneCode: zoneDef.code,
          ),
        );
      }

      final int count = math.max(1, zoneBuildings.length);
      currentCursorY += (count * rowStepY) + 38.0;
    }

    // Natural canvas height without artificial extra padding at bottom
    final double totalHeight = math.max(1300.0, currentCursorY + 24.0);

    return _CampusLayoutResult(
      markers: allMarkers,
      headers: allHeaders,
      totalHeight: totalHeight,
    );
  }

  int _determineZoneIndex(
    CampusBuildingSummary building,
    int index,
    int totalCount,
  ) {
    final name = building.buildingName.toLowerCase().trim();

    for (final canonical in _kCampusZones[0].canonicalNames) {
      if (name == canonical || name.contains(canonical)) {
        return 0;
      }
    }
    if (name.contains('bus parking') ||
        name.contains('hostel') ||
        name.contains('parking')) {
      return 0;
    }

    for (final canonical in _kCampusZones[2].canonicalNames) {
      if (name == canonical || name.contains(canonical)) {
        return 2;
      }
    }
    if (name.contains('engineering') ||
        name.contains('law') ||
        name.contains('sports')) {
      return 2;
    }

    for (final canonical in _kCampusZones[1].canonicalNames) {
      if (name == canonical || name.contains(canonical)) {
        return 1;
      }
    }
    if (name.contains('cafe') ||
        name.contains('cafeteria') ||
        name.contains('hotel management') ||
        name.contains('library')) {
      return 1;
    }

    if (totalCount <= 3) {
      return index % 3;
    }
    final int third = (totalCount / 3.0).ceil();
    if (index < third) return 0;
    if (index < third * 2) return 1;
    return 2;
  }

  List<Widget> _buildZoneHeaderWidgets(List<_ZoneHeaderLayout> headers) {
    return headers.map((h) {
      return Positioned(
        top: h.position.dy,
        left: 12,
        right: 12,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _MapColors.neutralBorder,
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: h.accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    h.code,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: h.accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(h.icon, size: 13, color: h.accentColor),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    h.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Building Markers: Clean, Single Footprint & Clear Highlight Callout
  // ---------------------------------------------------------------------------
  List<Widget> _buildBuildingMarkers({
    required List<_PositionedMarker> positionedMarkers,
    required Set<String> visibleBuildingIds,
    required CampusBuildingSummary? selected,
  }) {
    final List<Widget> markers = [];

    for (final posMarker in positionedMarkers) {
      final building = posMarker.building;
      if (!visibleBuildingIds.contains(building.buildingId)) {
        continue;
      }
      final bool isSelected = building.buildingId == selected?.buildingId;
      final bool hasActiveReports = building.activeReports > 0;

      markers.add(
        Positioned(
          left: posMarker.markerPos.dx - (posMarker.width / 2.0),
          top: posMarker.markerPos.dy - (posMarker.height / 2.0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectBuilding(building),
            child: SizedBox(
              width: posMarker.width,
              height: posMarker.height,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    height: posMarker.height,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? _MapColors.forestGreen : _MapColors.footprintFill,
                      borderRadius: BorderRadius.circular(isSelected ? 14 : 10),
                      border: Border.all(
                        color: isSelected ? _MapColors.forestGreen : _MapColors.footprintOutline,
                        width: isSelected ? 1.5 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? _MapColors.forestGreen.withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.04),
                          blurRadius: isSelected ? 10 : 3,
                          offset: Offset(0, isSelected ? 3 : 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasActiveReports
                              ? Icons.warning_amber_rounded
                              : (building.totalReports == 0
                                  ? Icons.eco_rounded
                                  : Icons.apartment_rounded),
                          size: 13,
                          color: isSelected
                              ? (hasActiveReports
                                  ? const Color(0xFFFFB3A0)
                                  : Colors.white)
                              : (hasActiveReports
                                  ? _MapColors.alertRed
                                  : _MapColors.forestGreen),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            building.buildingName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              color: isSelected ? Colors.white : _MapColors.forestGreen,
                            ),
                          ),
                        ),
                        if (hasActiveReports) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.5,
                              vertical: 1.0,
                            ),
                            decoration: BoxDecoration(
                              color: _MapColors.alertRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${building.activeReports}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Downward Pointer Pin Indicator when Selected
                  if (isSelected)
                    Positioned(
                      bottom: -5,
                      child: CustomPaint(
                        size: const Size(10, 6),
                        painter: _MarkerArrowPainter(_MapColors.forestGreen),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  // ---------------------------------------------------------------------------
  // Lower-Right Floating Controls (Locate & Navigation Arrow)
  // ---------------------------------------------------------------------------
  Widget _buildFloatingControls(CampusBuildingSummary? selected) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _MapColors.neutralBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: _MapColors.forestGreen.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.my_location_rounded, size: 19, color: _MapColors.forestGreen),
            onPressed: () => _locateOrRecenter(selected),
            tooltip: 'Locate selection',
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            padding: EdgeInsets.zero,
          ),
          Container(
            width: 22,
            height: 1,
            color: _MapColors.neutralBorder,
          ),
          IconButton(
            icon: const Icon(Icons.navigation_rounded, size: 18, color: _MapColors.forestGreen),
            onPressed: _resetView,
            tooltip: 'Campus North',
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Docked Selected-Building Details Bottom Sheet
  // ---------------------------------------------------------------------------
  Widget _buildDockedBuildingDetailsSheet(
    CampusBuildingSummary building, {
    Key? key,
  }) {
    final orderedCategories = _getOrderedCategories(building);
    final bool hasActive = building.activeReports > 0;

    return Container(
      key: key,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: _MapColors.neutralBorder, width: 1.2),
          left: BorderSide(color: _MapColors.neutralBorder, width: 1.0),
          right: BorderSide(color: _MapColors.neutralBorder, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Centered Drag Handle (36 x 4 logical pixels)
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Building Name, Timestamp, Close Button (No redundant badge)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          building.buildingName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _MapColors.forestGreen,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (building.lastReportAt != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 11,
                                color: _MapColors.neutralText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Last report: ${DateFormat('d MMM yyyy, h:mm a').format(building.lastReportAt!.toLocal())}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _MapColors.neutralText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            'No reports yet',
                            style: TextStyle(
                              fontSize: 11,
                              color: _MapColors.neutralText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  Semantics(
                    button: true,
                    label: 'Close building details',
                    child: InkWell(
                      onTap: () => setState(() => _isDetailsDismissed = true),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0F4F1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: _MapColors.neutralText,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 3-Column Summary Metrics: Total, Active, Resolved
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Total',
                      count: building.totalReports,
                      bgColor: _MapColors.statBg,
                      borderColor: _MapColors.neutralBorder,
                      labelColor: _MapColors.neutralText,
                      countColor: _MapColors.forestGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Active',
                      count: building.activeReports,
                      bgColor: hasActive ? _MapColors.alertRedBg : _MapColors.statBg,
                      borderColor: hasActive ? _MapColors.alertRedBorder : _MapColors.neutralBorder,
                      labelColor: hasActive ? _MapColors.alertRed : _MapColors.neutralText,
                      countColor: hasActive ? _MapColors.alertRed : _MapColors.neutralText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Resolved',
                      count: building.resolvedReports,
                      bgColor: _MapColors.statBg,
                      borderColor: _MapColors.neutralBorder,
                      labelColor: _MapColors.neutralText,
                      countColor: const Color(0xFF1EA05A),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Horizontally Scrollable Category Chips (Dynamic Ordering: Positive first)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: orderedCategories.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildCategoryChip(item),
                    );
                  }).toList(),
                ),
              ),

              // Optional verified GPS coordinates note
              if (building.reportsWithCoordinates > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 11,
                      color: _MapColors.neutralText,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${building.reportsWithCoordinates} of ${building.totalReports} report(s) include verified GPS coordinates',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _MapColors.neutralText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // Primary Action Row (Two Buttons side by side, 48px height, 12px gap)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReportIssueScreen(
                                initialBuildingName: building.buildingName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text(
                          'Report Issue',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _MapColors.forestGreen,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: _MapColors.forestGreen, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: hasActive
                            ? () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const MyReportsScreen(),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _MapColors.forestGreen,
                          disabledBackgroundColor: const Color(0xFFE2EBE5),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFF749F82),
                          elevation: hasActive ? 2 : 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(
                          hasActive
                              ? 'View Active Issue (${building.activeReports})'
                              : 'No Active Issues',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: hasActive ? Colors.white : const Color(0xFF749F82),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required int count,
    required Color bgColor,
    required Color borderColor,
    required Color labelColor,
    required Color countColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: countColor,
            ),
          ),
        ],
      ),
    );
  }

  List<_CategoryItem> _getOrderedCategories(CampusBuildingSummary building) {
    final items = [
      _CategoryItem(
        label: 'Water',
        count: building.waterReports,
        icon: Icons.water_drop_outlined,
        priority: 0,
      ),
      _CategoryItem(
        label: 'Waste',
        count: building.wasteReports,
        icon: Icons.delete_outline_rounded,
        priority: 1,
      ),
      _CategoryItem(
        label: 'Energy',
        count: building.electricityReports,
        icon: Icons.bolt_rounded,
        priority: 2,
      ),
      _CategoryItem(
        label: 'Infrastructure',
        count: building.infrastructureReports,
        icon: Icons.handyman_outlined,
        priority: 3,
      ),
      _CategoryItem(
        label: 'Greenery',
        count: building.greeneryReports,
        icon: Icons.park_outlined,
        priority: 4,
      ),
      _CategoryItem(
        label: 'Cleanliness',
        count: building.cleanlinessReports,
        icon: Icons.cleaning_services_outlined,
        priority: 5,
      ),
    ];

    if (building.otherReports > 0) {
      items.add(
        _CategoryItem(
          label: 'Other',
          count: building.otherReports,
          icon: Icons.help_outline_rounded,
          priority: 6,
        ),
      );
    }

    items.sort((a, b) {
      final aHas = a.count > 0;
      final bHas = b.count > 0;
      if (aHas != bHas) {
        return aHas ? -1 : 1;
      }
      if (a.count != b.count) {
        return b.count.compareTo(a.count);
      }
      return a.priority.compareTo(b.priority);
    });

    return items;
  }

  Widget _buildCategoryChip(_CategoryItem item) {
    final bool hasReports = item.count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasReports ? _MapColors.alertRedBg : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasReports ? _MapColors.alertRedBorder : _MapColors.neutralBorder,
          width: 1.1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            item.icon,
            size: 12,
            color: hasReports ? _MapColors.alertRed : _MapColors.neutralText,
          ),
          const SizedBox(width: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: hasReports ? FontWeight.w700 : FontWeight.w600,
              color: hasReports ? _MapColors.alertRed : _MapColors.forestGreen,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
            decoration: BoxDecoration(
              color: hasReports ? Colors.white : const Color(0xFFF0F4F1),
              borderRadius: BorderRadius.circular(6),
              border: hasReports
                  ? Border.all(color: _MapColors.alertRedBorder, width: 0.8)
                  : null,
            ),
            child: Text(
              '${item.count}',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: hasReports ? _MapColors.alertRed : _MapColors.neutralText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.domain_disabled_rounded,
              color: _MapColors.neutralText,
              size: 44,
            ),
            const SizedBox(height: 10),
            Text(
              'No active campus buildings',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'No active buildings were found in the database.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: _MapColors.neutralText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: _MapColors.alertRed,
              size: 44,
            ),
            const SizedBox(height: 10),
            Text(
              'Unable to load campus map',
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Could not connect to Supabase. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(color: _MapColors.neutralText),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(buildingSummariesProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _MapColors.forestGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMatchesOverlay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _MapColors.neutralBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: _MapColors.neutralText,
            size: 38,
          ),
          const SizedBox(height: 8),
          Text(
            'No matching buildings',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'No buildings match the current search or filter.',
            style: AppTextStyles.bodySmall.copyWith(color: _MapColors.neutralText),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _activeFilter = CampusMapFilter.all;
              });
            },
            child: const Text('Reset filters'),
          ),
        ],
      ),
    );
  }
}

class _CampusLayoutResult {
  final List<_PositionedMarker> markers;
  final List<_ZoneHeaderLayout> headers;
  final double totalHeight;

  const _CampusLayoutResult({
    required this.markers,
    required this.headers,
    required this.totalHeight,
  });
}

// -----------------------------------------------------------------------------
// 2D Schematic Campus Landscape & Walkways CustomPainter
// -----------------------------------------------------------------------------
class _CampusSchematicMapPainter extends CustomPainter {
  final Animation<double> flowProgress;
  final Animation<double> transitionProgress;
  final String? previousBuildingId;
  final Offset? previousBuildingPos;
  final Offset? selectedBuildingPos;
  final List<_PositionedMarker> positionedMarkers;
  final List<_ZoneHeaderLayout> zoneHeaders;
  final bool showBuildings;
  final bool showWalkways;
  final bool showLandscaping;
  final String? selectedBuildingId;

  _CampusSchematicMapPainter({
    required super.repaint,
    required this.flowProgress,
    required this.transitionProgress,
    this.previousBuildingId,
    required this.previousBuildingPos,
    required this.selectedBuildingPos,
    required this.positionedMarkers,
    required this.zoneHeaders,
    required this.showBuildings,
    required this.showWalkways,
    required this.showLandscaping,
    this.selectedBuildingId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Campus Grounds Base Tint
    final bgPaint = Paint()..color = _MapColors.canvasBg;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Zone Lawns (if landscaping is enabled)
    if (showLandscaping) {
      final lawnPaint = Paint()
        ..color = _MapColors.lawnFill
        ..style = PaintingStyle.fill;

      // G1 Ground: North Hostel & Parking Grounds
      final g1Rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.50, 250.0),
          width: size.width * 0.92,
          height: 410.0,
        ),
        const Radius.circular(28),
      );
      canvas.drawRRect(g1Rect, lawnPaint);

      // G2 Ground: Central Café & Library Quad
      final g2Rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.50, 680.0),
          width: size.width * 0.90,
          height: 360.0,
        ),
        const Radius.circular(28),
      );
      canvas.drawRRect(g2Rect, lawnPaint);

      // G3 Ground: South Academic & Sports Complex
      final g3Rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.50, 1110.0),
          width: size.width * 0.92,
          height: 420.0,
        ),
        const Radius.circular(30),
      );
      canvas.drawRRect(g3Rect, lawnPaint);

      // Bioswale Stream along campus perimeter
      final bioswalePaint = Paint()
        ..color = const Color(0xFFD6E7E2)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final bioswalePath = Path();
      bioswalePath.moveTo(size.width * 0.08, 150.0);
      bioswalePath.cubicTo(
        size.width * 0.28,
        270.0,
        size.width * 0.72,
        420.0,
        size.width * 0.92,
        580.0,
      );
      bioswalePath.cubicTo(
        size.width * 0.75,
        760.0,
        size.width * 0.25,
        960.0,
        size.width * 0.10,
        1200.0,
      );
      canvas.drawPath(bioswalePath, bioswalePaint);
    }

    // 3. Paved Pedestrian Walkways & Connecting Promenades
    if (showWalkways) {
      final pathBasePaint = Paint()
        ..color = _MapColors.pathColor
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final connectorPaint = Paint()
        ..color = _MapColors.pathColor
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Central North-South Spine Promenade
      final spineStart = Offset(size.width * 0.50, 24.0);
      final spineEnd = Offset(size.width * 0.50, size.height - 24.0);
      canvas.drawLine(spineStart, spineEnd, pathBasePaint);

      // Branching walkways connecting the central spine to each building marker
      for (final marker in positionedMarkers) {
        final double spineX = size.width * 0.50;
        final double targetX = marker.markerPos.dx;
        final double targetY = marker.markerPos.dy;

        final path = Path();
        path.moveTo(spineX, targetY);
        path.lineTo(targetX, targetY);
        canvas.drawPath(path, connectorPaint);
      }

      // Ambient flow pulse along the spine promenade
      _drawFlowPulse(
        canvas: canvas,
        start: spineStart,
        end: spineEnd,
        progress: flowProgress.value,
      );
    }

    // 4. Building-to-Building Transition Animation
    // Visually animates along campus walkways from previously selected building to newly selected building
    if (previousBuildingPos != null &&
        selectedBuildingPos != null &&
        previousBuildingPos != selectedBuildingPos) {
      _drawBuildingTransitionPath(
        canvas: canvas,
        size: size,
        startPos: previousBuildingPos!,
        endPos: selectedBuildingPos!,
        progress: transitionProgress.value,
      );
    }

    // 5. Restrained 2D Tree Clusters in Quad Corners
    if (showLandscaping) {
      _drawTreeCluster(canvas, Offset(size.width * 0.18, 110.0));
      _drawTreeCluster(canvas, Offset(size.width * 0.82, 110.0));
      _drawTreeCluster(canvas, Offset(size.width * 0.20, 550.0));
      _drawTreeCluster(canvas, Offset(size.width * 0.80, 550.0));
      _drawTreeCluster(canvas, Offset(size.width * 0.18, 980.0));
      _drawTreeCluster(canvas, Offset(size.width * 0.82, 980.0));
    }
  }

  /// Draws a transition path connecting the previous building to the newly selected building
  /// along the schematic walkway network.
  void _drawBuildingTransitionPath({
    required Canvas canvas,
    required Size size,
    required Offset startPos,
    required Offset endPos,
    required double progress,
  }) {
    if (progress <= 0.0) return;

    final double spineX = size.width * 0.50;

    // Segment 1: startPos -> (spineX, startPos.dy)
    // Segment 2: (spineX, startPos.dy) -> (spineX, endPos.dy)
    // Segment 3: (spineX, endPos.dy) -> endPos
    final double d1 = (spineX - startPos.dx).abs();
    final double d2 = (endPos.dy - startPos.dy).abs();
    final double d3 = (endPos.dx - spineX).abs();
    final double totalDist = d1 + d2 + d3;
    if (totalDist <= 0) return;

    final double currentDist = progress.clamp(0.0, 1.0) * totalDist;

    // Subtle background route line connecting the two buildings
    final routeBgPaint = Paint()
      ..color = _MapColors.forestGreen.withValues(alpha: 0.20)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fullRoute = Path();
    fullRoute.moveTo(startPos.dx, startPos.dy);
    fullRoute.lineTo(spineX, startPos.dy);
    fullRoute.lineTo(spineX, endPos.dy);
    fullRoute.lineTo(endPos.dx, endPos.dy);
    canvas.drawPath(fullRoute, routeBgPaint);

    // Active progressive route line
    final activePaint = Paint()
      ..color = _MapColors.forestGreen.withValues(alpha: 0.85)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final activePath = Path();
    activePath.moveTo(startPos.dx, startPos.dy);

    Offset currentHead = startPos;

    if (currentDist <= d1) {
      final double segProgress = d1 > 0 ? currentDist / d1 : 1.0;
      currentHead = Offset(
        startPos.dx + (spineX - startPos.dx) * segProgress,
        startPos.dy,
      );
      activePath.lineTo(currentHead.dx, currentHead.dy);
    } else if (currentDist <= d1 + d2) {
      activePath.lineTo(spineX, startPos.dy);
      final double dInSeg2 = currentDist - d1;
      final double segProgress = d2 > 0 ? dInSeg2 / d2 : 1.0;
      currentHead = Offset(
        spineX,
        startPos.dy + (endPos.dy - startPos.dy) * segProgress,
      );
      activePath.lineTo(currentHead.dx, currentHead.dy);
    } else {
      activePath.lineTo(spineX, startPos.dy);
      activePath.lineTo(spineX, endPos.dy);
      final double dInSeg3 = currentDist - d1 - d2;
      final double segProgress = d3 > 0 ? dInSeg3 / d3 : 1.0;
      currentHead = Offset(
        spineX + (endPos.dx - spineX) * segProgress,
        endPos.dy,
      );
      activePath.lineTo(currentHead.dx, currentHead.dy);
    }

    canvas.drawPath(activePath, activePaint);

    // Traveling highlight dot along the line
    if (progress < 1.0) {
      final glowPaint = Paint()
        ..color = const Color(0xFF1EA05A).withValues(alpha: 0.40)
        ..style = PaintingStyle.fill;
      final corePaint = Paint()
        ..color = _MapColors.forestGreen
        ..style = PaintingStyle.fill;

      canvas.drawCircle(currentHead, 6.0, glowPaint);
      canvas.drawCircle(currentHead, 3.0, corePaint);
    }
  }

  void _drawFlowPulse({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required double progress,
  }) {
    final t = progress % 1.0;
    final double opacity =
        t < 0.15 ? (t / 0.15) : (t > 0.85 ? (1.0 - t) / 0.15 : 1.0);
    if (opacity <= 0.01) return;

    final pos = Offset.lerp(start, end, t)!;

    final glowPaint = Paint()
      ..color = const Color(0xFF1EA05A).withValues(alpha: 0.18 * opacity)
      ..style = PaintingStyle.fill;
    final corePaint = Paint()
      ..color = _MapColors.forestGreen.withValues(alpha: 0.35 * opacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(pos, 4.5, glowPaint);
    canvas.drawCircle(pos, 2.0, corePaint);
  }

  void _drawTreeCluster(Canvas canvas, Offset center) {
    final treePaint = Paint()
      ..color = _MapColors.treeFill.withValues(alpha: 0.60)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 5.0, treePaint);
    canvas.drawCircle(Offset(center.dx - 4.0, center.dy + 2.5), 4.0, treePaint);
    canvas.drawCircle(Offset(center.dx + 4.0, center.dy + 2.5), 4.0, treePaint);
  }

  @override
  bool shouldRepaint(covariant _CampusSchematicMapPainter oldDelegate) {
    return oldDelegate.flowProgress.value != flowProgress.value ||
        oldDelegate.transitionProgress.value != transitionProgress.value ||
        oldDelegate.previousBuildingId != previousBuildingId ||
        oldDelegate.previousBuildingPos != previousBuildingPos ||
        oldDelegate.selectedBuildingPos != selectedBuildingPos ||
        oldDelegate.showBuildings != showBuildings ||
        oldDelegate.showWalkways != showWalkways ||
        oldDelegate.showLandscaping != showLandscaping ||
        oldDelegate.selectedBuildingId != selectedBuildingId ||
        oldDelegate.positionedMarkers.length != positionedMarkers.length;
  }
}

// -----------------------------------------------------------------------------
// Small Downward Pointer Arrow for Selected Marker
// -----------------------------------------------------------------------------
class _MarkerArrowPainter extends CustomPainter {
  final Color color;
  _MarkerArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

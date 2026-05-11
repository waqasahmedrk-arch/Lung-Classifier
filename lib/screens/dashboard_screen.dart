// dashboard_screen.dart
//
// Changes vs previous version:
//   • Removed outer DashboardScreen floatingActionButton (was being overridden)
//   • _ScanTab now accepts onGetReport callback
//   • _ScanTabState._buildStackedFab() — stacks Get Report above preprocessing FAB
//   • _ScanTabState._buildGetReportFAB() — moved here from DashboardScreen
//   • _DashboardScreenState._buildGetReportFAB() removed

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../classifier.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/xray_validator.dart';
import 'get_report_screen.dart';
import 'login_screen.dart';
import '../widgets/model_status_card.dart';
import '../widgets/result_card.dart';
import '../widgets/class_bar_chart.dart';
import '../widgets/action_buttons.dart';
import '../widgets/validation_feedback_card.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const String kAppVersion     = '1.0.0';
const String kAppBuildNumber = '42';

// ─────────────────────────────────────────────────────────────────────────────
// Theme notifier
// ─────────────────────────────────────────────────────────────────────────────
class AppThemeNotifier extends ValueNotifier<ThemeMode> {
  AppThemeNotifier() : super(ThemeMode.dark);
  bool get isLight => value == ThemeMode.light;
  void toggle(bool enableLight) =>
      value = enableLight ? ThemeMode.light : ThemeMode.dark;
}

final AppThemeNotifier appThemeNotifier = AppThemeNotifier();

// ─────────────────────────────────────────────────────────────────────────────
// Analysis history model
// ─────────────────────────────────────────────────────────────────────────────
class AnalysisRecord {
  final DateTime timestamp;
  final String imagePath;
  final ClassificationResult result;

  const AnalysisRecord({
    required this.timestamp,
    required this.imagePath,
    required this.result,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// AppState enum
// ─────────────────────────────────────────────────────────────────────────────
enum AppState {
  initializing,
  ready,
  imageSelected,
  analyzing,
  result,
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// DashboardScreen — root with bottom nav
// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final List<AnalysisRecord> _history = [];
  bool _lightThemeEnabled = false;
  String _userName = '';
  String _userGender = 'Prefer not to say';
  File? _userAvatar;

  AnalysisRecord? get _latestRecord =>
      _history.isNotEmpty ? _history.first : null;

  void _addToHistory(AnalysisRecord record) =>
      setState(() => _history.insert(0, record));

  void _onProfileUpdated({
    required String name,
    required String gender,
    File? avatar,
  }) {
    setState(() {
      _userName = name;
      _userGender = gender;
      if (avatar != null) _userAvatar = avatar;
    });
  }

  void _onThemeChanged(bool enableLight) {
    setState(() => _lightThemeEnabled = enableLight);
    appThemeNotifier.toggle(enableLight);
  }

  // ── Navigate to Get Report screen ─────────────────────────────────────────
  void _openGetReport() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            GetReportScreen(latestRecord: _latestRecord),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      // ── onGetReport callback passed into _ScanTab ─────────────────────────
      _ScanTab(
        onNewRecord: _addToHistory,
        onGetReport: _openGetReport,
      ),
      _HistoryTab(history: _history),
      _ProfileTab(
        userName: _userName,
        userGender: _userGender,
        userAvatar: _userAvatar,
        onUpdated: _onProfileUpdated,
      ),
      _SettingsTab(
        lightThemeEnabled: _lightThemeEnabled,
        onThemeChanged: _onThemeChanged,
      ),
      const _AboutTab(),
    ];

    // ── No outer floatingActionButton — _ScanTab manages its own FABs ────────
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.document_scanner_outlined, Icons.document_scanner, 'Scan'),
      (Icons.history_outlined,          Icons.history,           'History'),
      (Icons.person_outline_rounded,    Icons.person_rounded,    'Profile'),
      (Icons.settings_outlined,         Icons.settings,          'Settings'),
      (Icons.info_outline_rounded,      Icons.info_rounded,      'About'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0C1828),
        border: Border(top: BorderSide(color: Color(0xFF1A2E45))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final (outlined, filled, label) = items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isActive ? filled : outlined,
                          key: ValueKey(isActive),
                          color: isActive
                              ? AppTheme.primary
                              : const Color(0xFF4A6580),
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive
                              ? AppTheme.primary
                              : const Color(0xFF4A6580),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Preprocessing step model
// ─────────────────────────────────────────────────────────────────────────────
class _PreprocessStep {
  final String title;
  final String description;
  final IconData icon;
  bool completed;

  _PreprocessStep({
    required this.title,
    required this.description,
    required this.icon,
    this.completed = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — Scan
// ─────────────────────────────────────────────────────────────────────────────
class _ScanTab extends StatefulWidget {
  final ValueChanged<AnalysisRecord> onNewRecord;
  // ── NEW: callback to open the Get Report screen ───────────────────────────
  final VoidCallback onGetReport;

  const _ScanTab({
    required this.onNewRecord,
    required this.onGetReport,
  });

  @override
  State<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<_ScanTab>
    with SingleTickerProviderStateMixin {
  // ── Core services ──────────────────────────────────────────────────────────
  final LungDiseaseClassifier _classifier = LungDiseaseClassifier();
  final ImagePicker _picker = ImagePicker();

  // ── State ──────────────────────────────────────────────────────────────────
  AppState _appState = AppState.initializing;
  String? _errorMessage;
  File? _selectedImage;
  ClassificationResult? _result;

  // ── Validation state ───────────────────────────────────────────────────────
  ValidationResult? _validationResult;
  bool _isValidating = false;

  // ── Preprocessing FAB ──────────────────────────────────────────────────────
  bool _fabExpanded = false;
  late AnimationController _fabAnimController;
  late Animation<double> _fabRotation;
  late Animation<double> _fabPanelSlide;

  final List<_PreprocessStep> _preprocessSteps = [
    _PreprocessStep(
      title: 'X-Ray Validation',
      description: 'Grayscale, brightness, contrast & edge checks',
      icon: Icons.verified_outlined,
    ),
    _PreprocessStep(
      title: 'Resize to 224×224',
      description: 'Bicubic interpolation to model input size',
      icon: Icons.aspect_ratio_rounded,
    ),
    _PreprocessStep(
      title: 'Pixel Normalization',
      description: 'EfficientNet preprocess: (pixel / 127.5) - 1.0',
      icon: Icons.tune_rounded,
    ),
    _PreprocessStep(
      title: 'Tensor Conversion',
      description: 'Reshape to [1, 224, 224, 3] float32 tensor',
      icon: Icons.memory_rounded,
    ),
    _PreprocessStep(
      title: 'Model Inference',
      description: 'EfficientNetB0 forward pass — softmax output',
      icon: Icons.psychology_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initModel();

    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fabRotation = Tween<double>(begin: 0, end: 0.375).animate(
      CurvedAnimation(parent: _fabAnimController, curve: Curves.easeInOut),
    );
    _fabPanelSlide = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _classifier.dispose();
    _fabAnimController.dispose();
    super.dispose();
  }

  // ── Model init ─────────────────────────────────────────────────────────────
  Future<void> _initModel() async {
    setState(() {
      _appState = AppState.initializing;
      _errorMessage = null;
    });
    try {
      await _classifier.loadModel();
      if (mounted) setState(() => _appState = AppState.ready);
    } catch (e) {
      if (mounted) {
        setState(() {
          _appState = AppState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // ── Image pick + validate ──────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 95,
      );
      if (picked == null) return;

      final imageFile = File(picked.path);

      setState(() {
        _selectedImage = imageFile;
        _result = null;
        _validationResult = null;
        _isValidating = true;
        _appState = AppState.ready;
        _fabExpanded = false;
        for (final step in _preprocessSteps) {
          step.completed = false;
        }
      });
      if (_fabAnimController.isCompleted) _fabAnimController.reverse();

      final validation = await XRayValidator.validate(imageFile);

      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _validationResult = validation;
        if (validation.isValid) {
          _preprocessSteps[0].completed = true;
          _appState = AppState.imageSelected;
        } else {
          _appState = AppState.ready;
        }
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Image selection failed: ${e.toString()}');
        setState(() {
          _appState = AppState.ready;
          _isValidating = false;
        });
      }
    }
  }

  Future<void> _startPrediction() async {
    if (_selectedImage == null || !_validationResult!.isValid) return;
    setState(() => _appState = AppState.analyzing);
    await _runClassification(_selectedImage!);
  }

  Future<void> _runClassification(File imageFile) async {
    for (int i = 1; i < _preprocessSteps.length - 1; i++) {
      await Future.delayed(const Duration(milliseconds: 380));
      if (mounted) setState(() => _preprocessSteps[i].completed = true);
    }

    try {
      final result = await _classifier.classifyFile(imageFile);
      if (mounted) {
        setState(() {
          _preprocessSteps.last.completed = true;
          _result = result;
          _appState = AppState.result;
        });
        widget.onNewRecord(AnalysisRecord(
          timestamp: DateTime.now(),
          imagePath: imageFile.path,
          result: result,
        ));
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Classification error: ${e.toString()}');
        setState(() => _appState = AppState.imageSelected);
      }
    }
  }

  void _reset() {
    setState(() {
      _selectedImage = null;
      _result = null;
      _validationResult = null;
      _isValidating = false;
      _appState = AppState.ready;
      _fabExpanded = false;
      for (final step in _preprocessSteps) {
        step.completed = false;
      }
    });
    if (_fabAnimController.isCompleted) _fabAnimController.reverse();
  }

  void _toggleFab() {
    setState(() => _fabExpanded = !_fabExpanded);
    _fabExpanded
        ? _fabAnimController.forward()
        : _fabAnimController.reverse();
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.colorCritical.withOpacity(0.9),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final showPreprocessFab =
        _appState == AppState.analyzing || _appState == AppState.result;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                ModelStatusCard(appState: _appState, onRetry: _initModel),
                const SizedBox(height: 20),
                _buildImageSection(),
                const SizedBox(height: 16),

                if (_isValidating) ...[
                  const ValidationLoadingCard(),
                  const SizedBox(height: 12),
                ],

                if (!_isValidating &&
                    _validationResult != null &&
                    !_validationResult!.isValid) ...[
                  ValidationFeedbackCard(
                    result: _validationResult!,
                    onDismiss: _reset,
                  ),
                  const SizedBox(height: 12),
                ],

                if (!_isValidating &&
                    _validationResult != null &&
                    _validationResult!.isValid &&
                    (_appState == AppState.imageSelected ||
                        _appState == AppState.analyzing ||
                        _appState == AppState.result)) ...[
                  _XRayValidBadge(),
                  const SizedBox(height: 12),
                ],

                if (_appState != AppState.initializing &&
                    _appState != AppState.error)
                  ActionButtons(
                    onCamera: () => _pickImage(ImageSource.camera),
                    onGallery: () => _pickImage(ImageSource.gallery),
                    onReset: _selectedImage != null ? _reset : null,
                    isAnalyzing: _appState == AppState.analyzing,
                    isModelReady: _classifier.isLoaded,
                  ),

                if (_appState == AppState.imageSelected &&
                    _validationResult != null &&
                    _validationResult!.isValid) ...[
                  const SizedBox(height: 16),
                  _buildStartPredictionButton(),
                ],

                if (_result != null) ...[
                  const SizedBox(height: 28),
                  ResultCard(result: _result!),
                  const SizedBox(height: 16),
                  ClassBarChart(allScores: _result!.allScores),
                  const SizedBox(height: 16),
                  _buildDisclaimerCard(),
                ],

                if (showPreprocessFab) const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
      // ── Single FAB slot: Get Report on top, preprocessing below ───────────
      floatingActionButton: _buildStackedFab(showPreprocessFab),
    );
  }

  // ── Stacked FAB: Get Report (top) + Preprocessing toggle (bottom) ──────────
  //
  //  Layout (bottom-aligned, right-aligned):
  //
  //  ┌─────────────────┐   ← Get Report pill   (always visible)
  //  └─────────────────┘
  //        12 px gap          (only when preprocessing FAB is shown)
  //  ┌──────────────────────────────────┐
  //  │  [preprocessing panel — slides]  │
  //  │  [Show/Hide FAB pill]            │   (only during analyzing / result)
  //  └──────────────────────────────────┘
  Widget _buildStackedFab(bool showPreprocessFab) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ── Get Report — always on top ──────────────────────────────────────
        _buildGetReportFAB(),

        // ── Preprocessing FAB — only during analysis / result ───────────────
        if (showPreprocessFab) ...[
          const SizedBox(height: 12),
          _buildPreprocessFab(),
        ],
      ],
    );
  }

  // ── Get Report pill FAB ────────────────────────────────────────────────────
  Widget _buildGetReportFAB() {
    return GestureDetector(
      onTap: widget.onGetReport,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF00897B),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00897B).withOpacity(0.40),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Get Report',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(
      duration: 2200.ms,
      delay: 1000.ms,
      color: Colors.white.withOpacity(0.15),
    );
  }

  // ── Sliver App Bar ─────────────────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppTheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1628), Color(0xFF0D1B2A)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30, right: -30,
                child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -20, left: 40,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.secondary.withOpacity(0.07),
                  ),
                ),
              ),
              Positioned(
                bottom: 20, left: 20, right: 20,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.medical_services_outlined,
                          color: AppTheme.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'LungScan AI',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
      ),
    );
  }

  // ── Image section ──────────────────────────────────────────────────────────
  Widget _buildImageSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _selectedImage != null ? 260 : 200,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isValidating
              ? AppTheme.primary.withOpacity(0.3)
              : _validationResult != null && _validationResult!.isValid
              ? const Color(0xFF00E676).withOpacity(0.4)
              : _validationResult != null && !_validationResult!.isValid
              ? AppTheme.colorCritical.withOpacity(0.4)
              : _selectedImage != null
              ? AppTheme.primary.withOpacity(0.4)
              : AppTheme.cardBorder,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _selectedImage != null
            ? _buildImagePreview()
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_selectedImage!, fit: BoxFit.cover),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
          ),
        ),
        if (_appState == AppState.analyzing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 3),
                  const SizedBox(height: 16),
                  Text('Analyzing X-Ray...',
                      style: GoogleFonts.inter(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        if (_isValidating)
          Container(
            color: Colors.black38,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.primary.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 12),
                  Text('Validating image...',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
        if (!_isValidating && _validationResult != null)
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _validationResult!.isValid
                    ? const Color(0xFF00E676).withOpacity(0.15)
                    : AppTheme.colorCritical.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _validationResult!.isValid
                      ? const Color(0xFF00E676).withOpacity(0.4)
                      : AppTheme.colorCritical.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _validationResult!.isValid
                        ? Icons.verified_outlined
                        : Icons.hide_image_outlined,
                    color: _validationResult!.isValid
                        ? const Color(0xFF00E676)
                        : AppTheme.colorCritical,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _validationResult!.isValid ? 'Valid X-Ray' : 'Not an X-Ray',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _validationResult!.isValid
                          ? const Color(0xFF00E676)
                          : AppTheme.colorCritical,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_appState == AppState.imageSelected &&
            _validationResult != null &&
            _validationResult!.isValid)
          Positioned(
            top: _validationResult != null ? 48 : 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border:
                Border.all(color: AppTheme.primary.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_outline,
                      color: AppTheme.primary, size: 12),
                  const SizedBox(width: 4),
                  Text('Ready',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        Positioned(
          bottom: 12, left: 12,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Text('Chest X-Ray',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_photo_alternate_outlined,
            size: 52, color: Colors.white12),
        const SizedBox(height: 14),
        Text('Select a Chest X-Ray',
            style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white38)),
        const SizedBox(height: 6),
        Text('Camera or gallery - grayscale X-rays only',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white24)),
      ],
    );
  }

  Widget _buildStartPredictionButton() {
    return GestureDetector(
      onTap: _startPrediction,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF00897B)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_outline_rounded,
                color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              'Start Prediction',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.2, end: 0, curve: Curves.easeOut, duration: 300.ms)
        .shimmer(duration: 1200.ms, delay: 400.ms, color: Colors.white24);
  }

  // ── Preprocessing FAB (Show/Hide panel) ───────────────────────────────────
  Widget _buildPreprocessFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizeTransition(
            sizeFactor: _fabPanelSlide,
            axisAlignment: 1.0,
            child: FadeTransition(
              opacity: _fabPanelSlide,
              child: _buildPreprocessPanel(),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _toggleFab,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _fabExpanded
                      ? [const Color(0xFF00897B), const Color(0xFF00897B)]
                      : [const Color(0xFF00897B), const Color(0xFF00897B)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (_fabExpanded
                        ? const Color(0xFF00897B)
                        : const Color(0xFF00897B))
                        .withOpacity(0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RotationTransition(
                    turns: _fabRotation,
                    child: const Icon(Icons.tune_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _fabExpanded ? 'Hide Steps' : 'Show Steps',
                      key: ValueKey(_fabExpanded),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreprocessPanel() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFF0C1828),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A2E45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.settings_suggest_outlined,
                      color: AppTheme.primary, size: 16),
                ),
                const SizedBox(width: 10),
                Text('Preprocessing Pipeline',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFF1A2E45)),
          ...List.generate(_preprocessSteps.length, (i) {
            final step = _preprocessSteps[i];
            final isLast = i == _preprocessSteps.length - 1;
            final isActive = _appState == AppState.analyzing &&
                !step.completed &&
                (i == 0 || _preprocessSteps[i - 1].completed);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: step.completed
                                  ? const Color(0xFF2ECC71)
                                  : isActive
                                  ? AppTheme.primary.withOpacity(0.2)
                                  : const Color(0xFF1A2E45),
                              border: Border.all(
                                color: step.completed
                                    ? const Color(0xFF2ECC71)
                                    : isActive
                                    ? AppTheme.primary
                                    : const Color(0xFF2A3E55),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: step.completed
                                  ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14)
                                  : isActive
                                  ? SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppTheme.primary,
                                ),
                              )
                                  : Icon(step.icon,
                                  color: const Color(0xFF4A6580),
                                  size: 13),
                            ),
                          ),
                          if (!isLast)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 2,
                              height: 20,
                              margin:
                              const EdgeInsets.symmetric(vertical: 3),
                              color: step.completed
                                  ? const Color(0xFF2ECC71).withOpacity(0.5)
                                  : const Color(0xFF1A2E45),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(step.title,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: step.completed
                                        ? const Color(0xFF2ECC71)
                                        : isActive
                                        ? Colors.white
                                        : const Color(0xFF6B8CAE),
                                  )),
                              const SizedBox(height: 2),
                              Text(step.description,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    color: const Color(0xFF4A6580),
                                    height: 1.4,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This tool is for research purposes only. Results should not '
                  'replace professional medical diagnosis. Always consult a '
                  'qualified healthcare provider.',
              style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: Colors.amber.shade200,
                  height: 1.5),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Validation widgets
// ─────────────────────────────────────────────────────────────────────────────
class _XRayValidBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined,
              color: Color(0xFF00E676), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Valid chest X-ray detected — ready for analysis',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF00E676),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — History
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final List<AnalysisRecord> history;
  const _HistoryTab({required this.history});

  Color _colorForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'covid':           return const Color(0xFFFF4757);
      case 'normal':          return const Color(0xFF2ECC71);
      case 'lung opacity':    return const Color(0xFFFF6B35);
      case 'viral pneumonia': return const Color(0xFFFFD93D);
      default:                return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: _buildAppBar('Analysis History'),
      body: history.isEmpty
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded,
                size: 64, color: Color(0xFF1A2E45)),
            const SizedBox(height: 16),
            Text('No analyses yet',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38)),
            const SizedBox(height: 6),
            Text('Scan an X-Ray to see results here',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.white24)),
          ],
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        itemCount: history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final rec = history[i];
          final label = rec.result.label;
          final conf =
          (rec.result.confidence * 100).toStringAsFixed(1);
          final color = _colorForLabel(label);

          return Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomLeft: Radius.circular(15),
                  ),
                  child: Image.file(
                    File(rec.imagePath),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFF1A2E45),
                      child: const Icon(Icons.broken_image_outlined,
                          color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color),
                            ),
                            const SizedBox(width: 7),
                            Text(label,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Confidence: $conf%',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.white54)),
                        const SizedBox(height: 6),
                        Text(_formatDate(rec.timestamp),
                            style: GoogleFonts.inter(
                                fontSize: 11, color: Colors.white30)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Icon(Icons.chevron_right_rounded,
                      color: Colors.white24, size: 20),
                ),
              ],
            ),
          ).animate().fadeIn(
              delay: Duration(milliseconds: i * 60), duration: 300.ms);
        },
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $h:$m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — Profile
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileTab extends StatefulWidget {
  final String userName;
  final String userGender;
  final File? userAvatar;
  final void Function({
  required String name,
  required String gender,
  File? avatar,
  }) onUpdated;

  const _ProfileTab({
    required this.userName,
    required this.userGender,
    required this.userAvatar,
    required this.onUpdated,
  });

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late TextEditingController _nameCtrl;
  late String _selectedGender;
  File? _avatarFile;
  bool _saving = false;

  final _genders = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.userName.isEmpty
            ? AuthService().userName ?? ''
            : widget.userName);
    _selectedGender = widget.userGender;
    _avatarFile = widget.userAvatar;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C1828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            _SheetOption(
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo',
              onTap: () async {
                Navigator.pop(ctx);
                final f = await _picker.pickImage(
                    source: ImageSource.camera, imageQuality: 90);
                if (f != null && mounted) {
                  setState(() => _avatarFile = File(f.path));
                }
              },
            ),
            _SheetOption(
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              onTap: () async {
                Navigator.pop(ctx);
                final f = await _picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 90);
                if (f != null && mounted) {
                  setState(() => _avatarFile = File(f.path));
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 600));
    widget.onUpdated(
      name: _nameCtrl.text.trim(),
      gender: _selectedGender,
      avatar: _avatarFile,
    );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Profile updated',
            style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFF2ECC71).withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  String get _initials {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: _buildAppBar('Profile'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)]),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF00897B).withOpacity(0.3),
                            blurRadius: 20)
                      ],
                    ),
                    child: _avatarFile != null
                        ? ClipOval(
                        child: Image.file(_avatarFile!,
                            fit: BoxFit.cover, width: 100, height: 100))
                        : Center(
                      child: Text(_initials,
                          style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: AppTheme.surface, width: 2),
                    ),
                    child:
                    const Icon(Icons.edit, size: 14, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(auth.userEmail ?? '',
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF6B8CAE))),
            const SizedBox(height: 36),
            _FieldLabel('Display Name'),
            const SizedBox(height: 8),
            _InputField(
              controller: _nameCtrl,
              hint: 'Enter your name',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 24),
            _FieldLabel('Gender'),
            const SizedBox(height: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedGender,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0F1F33),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF6B8CAE)),
                  style:
                  GoogleFonts.inter(fontSize: 14, color: Colors.white),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedGender = v);
                  },
                  items: _genders
                      .map((g) =>
                      DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.primary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : Text('Save Changes',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 4 — Settings
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsTab extends StatelessWidget {
  final bool lightThemeEnabled;
  final ValueChanged<bool> onThemeChanged;

  const _SettingsTab({
    required this.lightThemeEnabled,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: _buildAppBar('Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          _SectionHeader('Appearance'),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _ThemeToggleTile(
              lightEnabled: lightThemeEnabled,
              onChanged: onThemeChanged,
            ),
          ]),
          const SizedBox(height: 24),
          _SectionHeader('Legal'),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _NavTile(
              icon: Icons.gavel_outlined,
              label: 'Terms & Conditions',
              onTap: () => _showLegalSheet(context,
                  title: 'Terms & Conditions', body: _kTerms),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => _showLegalSheet(context,
                  title: 'Privacy Policy', body: _kPrivacy),
            ),
          ]),
          const SizedBox(height: 24),
          _SectionHeader('Account'),
          const SizedBox(height: 8),
          _SettingsCard(children: [
            _NavTile(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              isDestructive: true,
              onTap: () => _confirmLogout(context),
            ),
          ]),
        ],
      ),
    );
  }

  void _showLegalSheet(BuildContext context,
      {required String title, required String body}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C1828),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              child: Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Text(body,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF8BAFC8),
                        height: 1.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C1828),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1A2E45)),
        ),
        title: const Text('Sign Out',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: Color(0xFF6B8CAE))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B8CAE))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              AuthService().logout();
              Navigator.of(context).pushAndRemoveUntil(
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const LoginScreen(),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 400),
                ),
                    (route) => false,
              );
            },
            child: const Text('Sign Out',
                style: TextStyle(
                    color: Color(0xFFFF4757),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme toggle tile
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeToggleTile extends StatelessWidget {
  final bool lightEnabled;
  final ValueChanged<bool> onChanged;

  const _ThemeToggleTile({required this.lightEnabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: lightEnabled
                  ? const Color(0xFFFFA500).withOpacity(0.15)
                  : const Color(0xFF4A6580).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                lightEnabled
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                key: ValueKey(lightEnabled),
                color: lightEnabled
                    ? const Color(0xFFFFA500)
                    : const Color(0xFF4A6580),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      lightEnabled ? 'Light Theme' : 'Dark Theme',
                      key: ValueKey(lightEnabled),
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lightEnabled
                      ? 'Switch to dark color scheme'
                      : 'Switch to light color scheme',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: const Color(0xFF6B8CAE)),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: lightEnabled,
            onChanged: onChanged,
            activeColor: const Color(0xFFFFA500),
            trackColor: const Color(0xFF1A2E45),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 5 — About
// ─────────────────────────────────────────────────────────────────────────────
class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: _buildAppBar('About'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
        children: [
          Center(
            child: Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
                ),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8))
                ],
              ),
              child: const Center(
                child: Icon(Icons.medical_services_outlined,
                    color: Colors.white, size: 40),
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text('LungScan AI',
                style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('COVID-19 & Lung Disease Detection',
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF6B8CAE))),
          ),
          const SizedBox(height: 32),
          _SettingsCard(children: [
            _InfoTile(
                label: 'App Version',
                value: 'v$kAppVersion',
                icon: Icons.tag_rounded),
            _Divider(),
            _InfoTile(
                label: 'Build Number',
                value: kAppBuildNumber,
                icon: Icons.build_circle_outlined),
            _Divider(),
            _InfoTile(
                label: 'AI Model',
                value: 'EfficientNetB0',
                icon: Icons.memory_rounded),
            _Divider(),
            _InfoTile(label: 'Classes', value: '4', icon: Icons.category_outlined),
            _Divider(),
            _InfoTile(
                label: 'Input Resolution',
                value: '224 × 224',
                icon: Icons.aspect_ratio_rounded),
            _Divider(),
            _InfoTile(
                label: 'Validation',
                value: '4 heuristic checks',
                icon: Icons.verified_outlined),
          ]),
          const SizedBox(height: 24),
          _SectionHeader('Description'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Text(
              'LungScan AI uses a fine-tuned EfficientNetB0 model to classify '
                  'chest X-rays into four categories: COVID-19, Lung Opacity, '
                  'Normal, and Viral Pneumonia. An on-device X-ray validator '
                  'ensures only valid radiographs are processed. '
                  'Designed for research and educational use only.',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF8BAFC8),
                  height: 1.7),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.amber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'For research purposes only. Not a medical device. '
                        'Always consult a qualified healthcare professional.',
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.amber.shade200,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '© ${DateTime.now().year} LungScan AI',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────
PreferredSizeWidget _buildAppBar(String title) {
  return AppBar(
    backgroundColor: const Color(0xFF0C1828),
    automaticallyImplyLeading: false,
    title: Text(title,
        style: GoogleFonts.inter(
            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
    centerTitle: false,
    elevation: 0,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: const Color(0xFF1A2E45)),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B8CAE),
              letterSpacing: 0.4)),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            fontSize: 14, color: const Color(0xFF4A6580)),
        prefixIcon:
        Icon(icon, color: const Color(0xFF4A6580), size: 20),
        filled: true,
        fillColor: AppTheme.cardBg,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1A2E45)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1A2E45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: AppTheme.primary.withOpacity(0.6), width: 1.5),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text.toUpperCase(),
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF4A6580),
              letterSpacing: 1.2)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: const Color(0xFF1A2E45));
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? const Color(0xFFFF4757) : Colors.white;
    final iconColor =
    isDestructive ? const Color(0xFFFF4757) : AppTheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color)),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white)),
          ),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 13, color: const Color(0xFF6B8CAE))),
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      title: Text(label,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.white)),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legal copy
// ─────────────────────────────────────────────────────────────────────────────
const _kTerms = '''
Terms & Conditions

Last updated: January 2025

1. Acceptance of Terms
By downloading and using LungScan AI, you agree to these terms. If you do not agree, please uninstall the application.

2. Research Use Only
LungScan AI is intended solely for research and educational purposes. It is NOT a medical device and its output should NEVER be used as a basis for clinical diagnosis or treatment decisions.

3. No Medical Advice
The application does not provide medical advice. Always consult a qualified healthcare professional for diagnosis, treatment, and medical guidance.

4. Accuracy Disclaimer
AI model predictions may be inaccurate. The developers make no warranties, express or implied, regarding the accuracy or reliability of results.

5. Data & Privacy
Images you scan are processed locally on-device and are not transmitted to any server unless explicitly stated. Refer to our Privacy Policy for details.

6. Limitation of Liability
To the fullest extent permitted by law, the developers shall not be liable for any damages arising from use or inability to use this application.

7. Changes to Terms
We reserve the right to update these terms at any time. Continued use of the application constitutes acceptance of the revised terms.
''';

const _kPrivacy = '''
Privacy Policy

Last updated: January 2025

1. Information We Collect
- Account information (name, email) provided during registration.
- Images selected for analysis — processed locally on your device.
- Usage analytics (anonymous, aggregated) to improve the application.

2. How We Use Information
- To provide and improve the lung analysis functionality.
- To authenticate your account and personalise your experience.
- We do not sell or share your personal data with third parties.

3. Image Processing
All image analysis is performed locally on your device using an on-device TFLite model. Images are NOT uploaded to external servers.

4. Data Retention
You may delete your account and associated data at any time by contacting support.

5. Security
We implement industry-standard security measures to protect your information.

6. Children's Privacy
This application is not directed at children under 13. We do not knowingly collect data from children.

7. Contact
For privacy-related questions, contact us at privacy@lungscanai.example.com.
''';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/xray_validator.dart';
import '../main.dart'; // AppTheme

// ─────────────────────────────────────────────────────────────────────────────
// ValidationLoadingCard
// Shown while the XRayValidator is running in the background isolate.
// ─────────────────────────────────────────────────────────────────────────────
class ValidationLoadingCard extends StatelessWidget {
  const ValidationLoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary.withOpacity(0.8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Validating image…',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Running grayscale, brightness, contrast & edge checks',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF4A6580),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ValidationFeedbackCard
// Shown when XRayValidator returns isValid == false.
// Displays the rejection reason + a breakdown of which checks failed.
// ─────────────────────────────────────────────────────────────────────────────
class ValidationFeedbackCard extends StatelessWidget {
  final ValidationResult result;
  final VoidCallback onDismiss;

  const ValidationFeedbackCard({
    super.key,
    required this.result,
    required this.onDismiss,
  });

  // ── Check metadata ─────────────────────────────────────────────────────────
  static const _checkMeta = {
    'grayscale': (
    icon: Icons.invert_colors_outlined,
    label: 'Grayscale',
    hint: 'X-rays have very low color saturation',
    ),
    'brightness': (
    icon: Icons.brightness_6_outlined,
    label: 'Brightness',
    hint: 'X-rays are neither too dark nor overexposed',
    ),
    'contrast': (
    icon: Icons.contrast_outlined,
    label: 'Contrast',
    hint: 'X-rays show high bone/tissue contrast',
    ),
    'edges': (
    icon: Icons.grid_on_outlined,
    label: 'Edge Density',
    hint: 'X-rays contain clear structural boundaries',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final checks =
        result.diagnostics['checks'] as Map<dynamic, dynamic>? ?? {};

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.colorCritical.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.colorCritical.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.colorCritical.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.hide_image_outlined,
                    color: AppTheme.colorCritical,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Not a valid X-Ray',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.colorCritical,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        result.reason,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white54,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                // Dismiss button
                GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ────────────────────────────────────────────────────────
          Container(height: 1, color: AppTheme.colorCritical.withOpacity(0.15)),

          // ── Check breakdown ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(
              'CHECK BREAKDOWN',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4A6580),
                letterSpacing: 1.1,
              ),
            ),
          ),
          ...(_checkMeta.entries.map((entry) {
            final key = entry.key;
            final meta = entry.value;
            final passed = checks[key] == true;

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  // Status icon
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: passed
                          ? const Color(0xFF2ECC71).withOpacity(0.12)
                          : AppTheme.colorCritical.withOpacity(0.12),
                      border: Border.all(
                        color: passed
                            ? const Color(0xFF2ECC71).withOpacity(0.4)
                            : AppTheme.colorCritical.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      passed ? Icons.check_rounded : Icons.close_rounded,
                      size: 13,
                      color: passed
                          ? const Color(0xFF2ECC71)
                          : AppTheme.colorCritical,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Check icon
                  Icon(
                    meta.icon,
                    size: 14,
                    color: const Color(0xFF4A6580),
                  ),
                  const SizedBox(width: 7),
                  // Label + hint
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.label,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: passed ? Colors.white70 : Colors.white54,
                          ),
                        ),
                        Text(
                          meta.hint,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: const Color(0xFF4A6580),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Raw diagnostic value
                  _DiagnosticBadge(checkKey: key, diagnostics: result.diagnostics),
                ],
              ),
            );
          })),

          // ── Confidence bar ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'X-Ray Confidence',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF4A6580),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(result.confidence * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _confidenceColor(result.confidence),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: result.confidence,
                    minHeight: 5,
                    backgroundColor: const Color(0xFF1A2E45),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _confidenceColor(result.confidence),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Try again hint ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 14, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please upload a chest X-ray (frontal / PA view). '
                        'Color photos and non-radiographic images are rejected.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white38,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(
      begin: 0.08,
      end: 0,
      curve: Curves.easeOut,
      duration: 300.ms,
    );
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.75) return const Color(0xFF2ECC71);
    if (confidence >= 0.5) return Colors.amber;
    return AppTheme.colorCritical;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small badge showing the raw diagnostic value for each check
// ─────────────────────────────────────────────────────────────────────────────
class _DiagnosticBadge extends StatelessWidget {
  final String checkKey;
  final Map<String, dynamic> diagnostics;

  const _DiagnosticBadge({
    required this.checkKey,
    required this.diagnostics,
  });

  String _value() {
    switch (checkKey) {
      case 'grayscale':
        final v = diagnostics['saturation'];
        return v != null ? 'sat ${(v as double).toStringAsFixed(1)}' : '—';
      case 'brightness':
        final v = diagnostics['brightness'];
        return v != null ? '${(v as double).toStringAsFixed(1)} lum' : '—';
      case 'contrast':
        final v = diagnostics['contrast'];
        return v != null ? 'σ ${(v as double).toStringAsFixed(1)}' : '—';
      case 'edges':
        final v = diagnostics['edgeDensity'];
        return v != null
            ? '${((v as double) * 100).toStringAsFixed(1)}%'
            : '—';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1828),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1A2E45)),
      ),
      child: Text(
        _value(),
        style: GoogleFonts.robotoMono(
          fontSize: 10,
          color: const Color(0xFF4A6580),
        ),
      ),
    );
  }
}
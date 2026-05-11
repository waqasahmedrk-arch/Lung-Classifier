// ─────────────────────────────────────────────────────────────────────────────
// lib/services/xray_validator.dart  — COMPLETE FIXED FILE
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ValidationResult {
  final bool isValid;
  final String reason;
  final double confidence;
  final Map<String, dynamic> diagnostics;

  const ValidationResult({
    required this.isValid,
    required this.reason,
    required this.confidence,
    required this.diagnostics,
  });

  @override
  String toString() =>
      'ValidationResult(valid=$isValid, '
          'confidence=${(confidence * 100).toStringAsFixed(1)}%, '
          'reason=$reason)';
}

class XRayValidator {
  // ── Tightened thresholds ───────────────────────────────────────────────────

  /// X-rays are nearly pure grayscale — very low saturation.
  /// Lowered from 30 → 18 to reject slightly-tinted photos.
  static const double _maxSaturation = 18.0;

  /// X-rays have a mid-range brightness — not too dark, not too bright.
  /// Tightened range: was 25–220, now 30–200.
  static const double _minBrightness = 30.0;
  static const double _maxBrightness = 200.0;

  /// X-rays have HIGH contrast (bone vs air vs soft tissue).
  /// Raised from 35 → 45 — flat document scans typically score ~25–38.
  static const double _minContrast = 45.0;

  /// X-rays have DENSE, fine-grained structural edges (ribs, lung borders).
  /// Raised from 0.04 → 0.08 — document text has fewer, coarser edges.
  static const double _minEdgeDensity = 0.08;

  /// X-ray aspect ratio must be roughly square (portrait chest X-ray).
  /// Landscape photos (wider than tall) are rejected.
  static const double _maxAspectRatio = 1.4; // width/height

  /// ALL 4 pixel checks must pass (raised from 3 → 4).
  /// This eliminates the "3 out of 4 is good enough" loophole.
  static const int _minPassingChecks = 4;

  // ── Public API ─────────────────────────────────────────────────────────────
  static Future<ValidationResult> validate(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return await compute(_validateInIsolate, bytes);
    } catch (e) {
      debugPrint('XRayValidator error: $e');
      return ValidationResult(
        isValid: false,
        reason: 'Could not read image file.',
        confidence: 0.0,
        diagnostics: {'error': e.toString()},
      );
    }
  }

  static ValidationResult _validateInIsolate(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) {
      return const ValidationResult(
        isValid: false,
        reason: 'Invalid or corrupted image file.',
        confidence: 0.0,
        diagnostics: {},
      );
    }

    // ── Check 0: Aspect ratio guard (before pixel analysis) ───────────────
    // Chest X-rays are always portrait or near-square.
    // A landscape photo (e.g. 16:9 selfie) is rejected immediately.
    final aspectRatio = image.width / image.height;
    if (aspectRatio > _maxAspectRatio) {
      return ValidationResult(
        isValid: false,
        reason: 'Image orientation is landscape. '
            'Chest X-rays are always portrait or square.',
        confidence: 0.0,
        diagnostics: {
          'aspectRatio': aspectRatio,
          'checks': {
            'grayscale': false,
            'brightness': false,
            'contrast': false,
            'edges': false,
          },
          'passCount': 0,
        },
      );
    }

    // Downscale to 128×128 for fast processing
    final small = img.copyResize(image, width: 128, height: 128);

    final saturation = _avgSaturation(small);
    final brightness = _avgBrightness(small);
    final contrast = _stdDevBrightness(small);
    final edgeDensity = _edgeDensity(small);

    // ── Compute histogram skew (X-rays have bimodal histograms) ───────────
    final histSkew = _brightnessHistogramSkew(small);

    final checks = {
      // Very strict grayscale: reject anything with noticeable color tint
      'grayscale': saturation < _maxSaturation,

      // Chest X-ray brightness sweet spot
      'brightness': brightness >= _minBrightness &&
          brightness <= _maxBrightness,

      // High contrast mandatory — document scans fail here
      'contrast': contrast >= _minContrast,

      // Dense fine edges — ribs/lungs produce far more edges than text/objects
      'edges': edgeDensity >= _minEdgeDensity,
    };

    final passCount = checks.values.where((v) => v).length;

    // ── Bonus check: histogram bimodality ─────────────────────────────────
    // X-rays show two peaks (dark lung fields + bright bone).
    // If pixel checks all pass but histogram is unimodal → likely a
    // plain grayscale photo. Reduces confidence but doesn't hard-fail.
    final bimodalBonus = histSkew > 0.15 ? 1 : 0;

    // isValid requires ALL 4 checks to pass
    final isValid = passCount >= _minPassingChecks;

    // Confidence: weighted by pass count + histogram bonus
    final confidence =
    ((passCount + bimodalBonus) / (_minPassingChecks + 1))
        .clamp(0.0, 1.0);

    final failedChecks = checks.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();

    final reason = isValid
        ? 'Image appears to be a valid chest X-ray.'
        : _buildRejectionMessage(
        failedChecks, saturation, brightness, contrast, edgeDensity);

    debugPrint(
      'XRayValidator → '
          'sat=${saturation.toStringAsFixed(1)} '
          'bright=${brightness.toStringAsFixed(1)} '
          'contrast=${contrast.toStringAsFixed(1)} '
          'edges=${(edgeDensity * 100).toStringAsFixed(2)}% '
          'skew=${histSkew.toStringAsFixed(3)} '
          'pass=$passCount/4 valid=$isValid',
    );

    return ValidationResult(
      isValid: isValid,
      reason: reason,
      confidence: confidence,
      diagnostics: {
        'saturation': saturation,
        'brightness': brightness,
        'contrast': contrast,
        'edgeDensity': edgeDensity,
        'histogramSkew': histSkew,
        'aspectRatio': aspectRatio,
        'checks': checks,
        'passCount': passCount,
      },
    );
  }

  // ── Check 1: Grayscale ─────────────────────────────────────────────────────
  static double _avgSaturation(img.Image image) {
    double total = 0;
    int count = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();
        final maxC = max(r, max(g, b));
        final minC = min(r, min(g, b));
        if (maxC > 0) {
          total += ((maxC - minC) / maxC) * 255.0;
          count++;
        }
      }
    }
    return count > 0 ? total / count : 0;
  }

  // ── Check 2: Brightness ────────────────────────────────────────────────────
  static double _avgBrightness(img.Image image) {
    double total = 0;
    int count = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        total += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }

  // ── Check 3: Contrast ──────────────────────────────────────────────────────
  static double _stdDevBrightness(img.Image image) {
    final lums = <double>[];
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        lums.add(0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
      }
    }
    final mean = lums.reduce((a, b) => a + b) / lums.length;
    final variance =
        lums.map((l) => (l - mean) * (l - mean)).reduce((a, b) => a + b) /
            lums.length;
    return sqrt(variance);
  }

  // ── Check 4: Edge density (Sobel) ─────────────────────────────────────────
  static double _edgeDensity(img.Image image) {
    int edgePixels = 0;
    // Raised edge threshold: 30 → 40 to ignore weak texture edges in photos
    const threshold = 40.0;
    final w = image.width;
    final h = image.height;

    double lum(int x, int y) {
      if (x < 0 || x >= w || y < 0 || y >= h) return 0;
      final p = image.getPixel(x, y);
      return 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    }

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final gx = -lum(x - 1, y - 1) + lum(x + 1, y - 1) +
            -2 * lum(x - 1, y) + 2 * lum(x + 1, y) +
            -lum(x - 1, y + 1) + lum(x + 1, y + 1);
        final gy = -lum(x - 1, y - 1) - 2 * lum(x, y - 1) -
            lum(x + 1, y - 1) + lum(x - 1, y + 1) +
            2 * lum(x, y + 1) + lum(x + 1, y + 1);
        if (sqrt(gx * gx + gy * gy) > threshold) edgePixels++;
      }
    }
    return edgePixels / ((w - 2) * (h - 2));
  }

  // ── Bonus: Histogram bimodality skew ──────────────────────────────────────
  // X-rays have two distinct brightness clusters (dark air / bright bone).
  // We measure the "valley depth" between the two halves of the histogram.
  static double _brightnessHistogramSkew(img.Image image) {
    final hist = List<int>.filled(256, 0);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        final lum =
        (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
        hist[lum]++;
      }
    }
    final total = image.width * image.height;

    // Low half (0–127) vs high half (128–255) mass
    final lowMass =
        hist.sublist(0, 128).reduce((a, b) => a + b) / total;
    final highMass =
        hist.sublist(128, 256).reduce((a, b) => a + b) / total;

    // Mid-range valley (64–192) — X-rays have a pronounced dip here
    final midMass =
        hist.sublist(64, 192).reduce((a, b) => a + b) / total;

    // Skew = imbalance between extremes vs middle
    return ((lowMass + highMass) - midMass).abs();
  }

  // ── Rejection message ──────────────────────────────────────────────────────
  static String _buildRejectionMessage(
      List<String> failedChecks,
      double saturation,
      double brightness,
      double contrast,
      double edgeDensity,
      ) {
    if (failedChecks.contains('grayscale')) {
      return 'Color image detected (saturation=${saturation.toStringAsFixed(1)}). '
          'X-rays are grayscale. Please upload a chest X-ray.';
    }
    if (failedChecks.contains('brightness')) {
      if (brightness < _minBrightness) {
        return 'Image is too dark (brightness=${brightness.toStringAsFixed(1)}). '
            'Please upload a properly exposed X-ray.';
      }
      return 'Image is overexposed (brightness=${brightness.toStringAsFixed(1)}). '
          'Please upload a valid chest X-ray.';
    }
    if (failedChecks.contains('contrast')) {
      return 'Insufficient contrast (σ=${contrast.toStringAsFixed(1)}, '
          'need ≥${_minContrast.toStringAsFixed(0)}). '
          'X-rays show strong bone/tissue contrast. '
          'This appears to be a flat image or document scan.';
    }
    if (failedChecks.contains('edges')) {
      return 'Insufficient structural detail '
          '(edge density=${(edgeDensity * 100).toStringAsFixed(1)}%, '
          'need ≥${(_minEdgeDensity * 100).toStringAsFixed(0)}%). '
          'Please upload a clear chest X-ray.';
    }
    return 'This image does not match chest X-ray characteristics. '
        'Please upload a frontal chest radiograph.';
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../classifier.dart';
import '../main.dart';

class ResultCard extends StatelessWidget {
  final ClassificationResult result;

  const ResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final severity = LungDiseaseClassifier.getSeverity(result.label);
    final color = _colorForSeverity(severity);
    final icon = _iconForSeverity(severity);
    final confidencePct = (result.confidence * 100).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Diagnosis',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white38,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      result.label,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Confidence badge
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Text(
                  '$confidencePct%',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Confidence bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: result.confidence,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),

          const SizedBox(height: 16),

          // Severity chip + inference time
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  LungDiseaseClassifier.getSeverityLabel(severity),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.timer_outlined, size: 14, color: Colors.white24),
              const SizedBox(width: 4),
              Text(
                '${result.inferenceTimeMs}ms',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.white24,
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  Color _colorForSeverity(Severity severity) {
    switch (severity) {
      case Severity.normal:
        return AppTheme.colorNormal;
      case Severity.moderate:
        return AppTheme.colorModerate;
      case Severity.high:
        return AppTheme.colorHigh;
      case Severity.critical:
        return AppTheme.colorCritical;
    }
  }

  IconData _iconForSeverity(Severity severity) {
    switch (severity) {
      case Severity.normal:
        return Icons.check_circle_outline;
      case Severity.moderate:
        return Icons.warning_amber_outlined;
      case Severity.high:
        return Icons.report_outlined;
      case Severity.critical:
        return Icons.coronavirus_outlined;
    }
  }
}

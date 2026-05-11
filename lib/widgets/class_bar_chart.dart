import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class ClassBarChart extends StatelessWidget {
  final Map<String, double> allScores;

  const ClassBarChart({super.key, required this.allScores});

  // Each class has a distinct color
  static const Map<String, Color> classColors = {
    'COVID': AppTheme.colorCritical,
    'Lung Opacity': AppTheme.colorHigh,
    'Normal': AppTheme.colorNormal,
    'Viral Pneumonia': AppTheme.colorModerate,
  };

  @override
  Widget build(BuildContext context) {
    // Sort by score descending
    final sorted = allScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLASS PROBABILITIES',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white38,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            final color = classColors[e.key] ?? AppTheme.primary;
            final pct = (e.value * 100).toStringAsFixed(2);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            e.key,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$pct%',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: e.value),
                      duration: Duration(milliseconds: 600 + i * 100),
                      curve: Curves.easeOut,
                      builder: (context, value, _) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.white.withOpacity(0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                              color.withOpacity(0.85)),
                          minHeight: 8,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(
              duration: 400.ms,
              delay: Duration(milliseconds: 100 + i * 80),
            );
          }),
        ],
      ),
    );
  }
}

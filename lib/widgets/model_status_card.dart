import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/dashboard_screen.dart';
import '../main.dart';

class ModelStatusCard extends StatelessWidget {
  final AppState appState;
  final VoidCallback onRetry;

  const ModelStatusCard({
    super.key,
    required this.appState,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: config.bgColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: config.bgColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Icon / spinner
          SizedBox(
            width: 36,
            height: 36,
            child: appState == AppState.initializing
                ? CircularProgressIndicator(
              strokeWidth: 2.5,
              color: config.bgColor,
            )
                : Container(
              decoration: BoxDecoration(
                color: config.bgColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(config.icon, color: config.bgColor, size: 18),
            ),
          ),
          const SizedBox(width: 14),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  config.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),

          // Retry button on error
          if (appState == AppState.error)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 15),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),

          // Status dot
          if (appState != AppState.error)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: config.bgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: config.bgColor.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: -0.1, end: 0, duration: 400.ms);
  }

  _StatusConfig _getConfig() {
    switch (appState) {
      case AppState.initializing:
        return _StatusConfig(
          title: 'Loading Model',
          subtitle: 'Initializing EfficientNetB0 TFLite interpreter...',
          icon: Icons.hourglass_top_rounded,
          bgColor: Colors.amber,
        );
      case AppState.ready:
        return _StatusConfig(
          title: 'Model Ready',
          subtitle: 'EfficientNetB0 · 4 classes · 224×224 input',
          icon: Icons.check_circle_outline,
          bgColor: AppTheme.colorNormal,
        );
      case AppState.imageSelected:
        return _StatusConfig(
          title: 'Image Selected',
          subtitle: 'Tap "Start Prediction" to run analysis',
          icon: Icons.image_outlined,
          bgColor: AppTheme.primary,
        );
      case AppState.analyzing:
        return _StatusConfig(
          title: 'Analyzing',
          subtitle: 'Running inference on chest X-ray...',
          icon: Icons.analytics_outlined,
          bgColor: AppTheme.primary,
        );
      case AppState.result:
        return _StatusConfig(
          title: 'Analysis Complete',
          subtitle: 'Classification result available below',
          icon: Icons.task_alt_rounded,
          bgColor: AppTheme.primary,
        );
      case AppState.error:
        return _StatusConfig(
          title: 'Model Error',
          subtitle: 'Could not load TFLite model from assets',
          icon: Icons.error_outline,
          bgColor: AppTheme.colorCritical,
        );
    }
  }
}

class _StatusConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color bgColor;

  const _StatusConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.bgColor,
  });
}
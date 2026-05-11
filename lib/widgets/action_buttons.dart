import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onReset;
  final bool isAnalyzing;
  final bool isModelReady;

  const ActionButtons({
    super.key,
    required this.onCamera,
    required this.onGallery,
    required this.onReset,
    required this.isAnalyzing,
    required this.isModelReady,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // Camera button
            Expanded(
              child: _PrimaryButton(
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: isModelReady && !isAnalyzing ? onCamera : null,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00897B), Color(0xFF00897B)],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Gallery button
            Expanded(
              child: _PrimaryButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: isModelReady && !isAnalyzing ? onGallery : null,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00897B), Color(0xFF00897B)],
                ),
              ),
            ),
          ],
        ),
        if (onReset != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isAnalyzing ? null : onReset,
              icon: const Icon(Icons.refresh, size: 16),
              label: Text(
                'Clear & Analyze New Image',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white12),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }
}

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Gradient gradient;

  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: isDisabled ? null : gradient,
            color: isDisabled ? Colors.white10 : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isDisabled
                ? []
                : [
              BoxShadow(
                color: (gradient as LinearGradient)
                    .colors
                    .first
                    .withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

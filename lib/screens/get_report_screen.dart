import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import 'dashboard_screen.dart';
import '../classifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PdfColor opacity helper — replaces the removed .shade() method
// ─────────────────────────────────────────────────────────────────────────────
extension _PdfColorExt on PdfColor {
  PdfColor withAlpha(double opacity) => PdfColor(red, green, blue, opacity);
}

// ─────────────────────────────────────────────────────────────────────────────
// GetReportScreen
// ─────────────────────────────────────────────────────────────────────────────
class GetReportScreen extends StatefulWidget {
  final AnalysisRecord? latestRecord;
  const GetReportScreen({super.key, this.latestRecord});

  @override
  State<GetReportScreen> createState() => _GetReportScreenState();
}

class _GetReportScreenState extends State<GetReportScreen> {
  // ── Controllers ──────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _patientIdCtrl;
  final _nameCtrl        = TextEditingController();
  final _fatherNameCtrl  = TextEditingController();
  final _emailCtrl       = TextEditingController();
  final _dobCtrl         = TextEditingController();

  // ── Dropdown values ───────────────────────────────────────────────────────────
  String _selectedGender     = 'Male';
  String _selectedBloodGroup = 'A+';
  DateTime? _selectedDOB;

  // ── State ─────────────────────────────────────────────────────────────────────
  bool _isGenerating = false;

  static const _genders     = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _patientIdCtrl = TextEditingController(text: _generatePatientId());
  }

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _nameCtrl.dispose();
    _fatherNameCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────
  String _generatePatientId() {
    final rand   = Random();
    final suffix = List.generate(6, (_) => rand.nextInt(10)).join();
    return 'LS-${DateTime.now().year}-$suffix';
  }

  void _regenerateId() =>
      setState(() => _patientIdCtrl.text = _generatePatientId());

  Future<void> _pickDOB() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDOB ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primary,
            surface: Color(0xFF0C1828),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF0C1828),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDOB  = picked;
        _dobCtrl.text = DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  String _calculateAge() {
    if (_selectedDOB == null) return 'N/A';
    final now = DateTime.now();
    int age   = now.year - _selectedDOB!.year;
    if (now.month < _selectedDOB!.month ||
        (now.month == _selectedDOB!.month && now.day < _selectedDOB!.day)) {
      age--;
    }
    return '$age years';
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Severity helpers — self-contained, no dependency on classifier.dart statics
  // ─────────────────────────────────────────────────────────────────────────────
  PdfColor _severityColor(String label) {
    switch (label.toLowerCase()) {
      case 'normal':          return PdfColor.fromHex('#2ECC71');
      case 'viral pneumonia': return PdfColor.fromHex('#FFD93D');
      case 'lung opacity':    return PdfColor.fromHex('#FF6B35');
      case 'covid':           return PdfColor.fromHex('#FF4757');
      default:                return PdfColor.fromHex('#00D4FF');
    }
  }

  String _severityLabel(String label) {
    switch (label.toLowerCase()) {
      case 'normal':          return 'No Pathology Detected';
      case 'viral pneumonia': return 'Abnormal — Viral Origin';
      case 'lung opacity':    return 'Abnormal — Opacity Present';
      case 'covid':           return 'Critical — Immediate Review';
      default:                return 'Undetermined';
    }
  }

  String _clinicalNote(String label) {
    switch (label.toLowerCase()) {
      case 'normal':
        return 'AI analysis did not detect significant pathological findings. '
            'Lung fields appear clear with no obvious consolidation or opacity. '
            'Routine follow-up as clinically indicated.';
      case 'viral pneumonia':
        return 'AI analysis suggests viral pneumonia pattern. '
            'Interstitial infiltrates consistent with viral etiology may be present. '
            'Clinical evaluation and appropriate antiviral management recommended.';
      case 'lung opacity':
        return 'AI analysis detected lung opacity patterns. '
            'This may indicate consolidation, fluid accumulation, or other pathology. '
            'Further imaging (CT scan) and pulmonologist consultation advised.';
      case 'covid':
        return 'AI analysis suggests possible COVID-19 findings. '
            'Characteristic bilateral ground-glass opacities may be present. '
            'Immediate clinical correlation and PCR testing recommended.';
      default:
        return 'Unable to determine clinical findings. Please consult a qualified radiologist.';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PDF Generation — all .shade() removed, replaced with .withAlpha()
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _generateReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDOB == null) {
      _showSnack('Please select date of birth.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isGenerating = true);

    try {
      final pdf    = pw.Document();
      final now    = DateTime.now();
      final dateStr = DateFormat('dd MMM yyyy').format(now);
      final timeStr = DateFormat('HH:mm').format(now);
      final result  = widget.latestRecord?.result;

      // ── PDF colours — PdfColor.fromHex only, no .shade() ─────────────────
      final primaryColor  = PdfColor.fromHex('#00D4FF');
      final darkBg        = PdfColor.fromHex('#0A1628');
      final cardBg        = PdfColor.fromHex('#0C1C30');
      final borderColor   = PdfColor.fromHex('#1A2E45');
      final textWhite     = PdfColors.white;
      final textGrey      = PdfColor.fromHex('#8BAFC8');
      final accentPurple  = PdfColor.fromHex('#7B2FFF');
      final green         = PdfColor.fromHex('#2ECC71');
      final red           = PdfColor.fromHex('#FF4757');
      final orange        = PdfColor.fromHex('#FF6B35');
      final yellow        = PdfColor.fromHex('#FFD93D');
      final warningBg     = PdfColor.fromHex('#1A1400');
      final warningBorder = PdfColor.fromHex('#3D3000');
      final warningText   = PdfColor.fromHex('#FFD93D');
      final warningBody   = PdfColor.fromHex('#C8A800');

      // ── Severity colour — uses local helper, not classifier statics ───────
      final severityColor = result != null
          ? _severityColor(result.label)
          : primaryColor;
      final severityLbl = result != null
          ? _severityLabel(result.label)
          : 'N/A';

      // ── Text styles ───────────────────────────────────────────────────────
      final styleHeading = pw.TextStyle(
        font: pw.Font.helveticaBold(),
        fontSize: 22,
        color: textWhite,
        letterSpacing: -0.5,
      );
      final styleSubtitle = pw.TextStyle(
        font: pw.Font.helvetica(),
        fontSize: 11,
        color: textGrey,
      );
      final styleSectionHeader = pw.TextStyle(
        font: pw.Font.helveticaBold(),
        fontSize: 9,
        color: primaryColor,
        letterSpacing: 1.5,
      );
      final styleLabel = pw.TextStyle(
        font: pw.Font.helvetica(),
        fontSize: 10,
        color: textGrey,
      );
      final styleValue = pw.TextStyle(
        font: pw.Font.helveticaBold(),
        fontSize: 12,
        color: textWhite,
      );
      final styleSmall = pw.TextStyle(
        font: pw.Font.helvetica(),
        fontSize: 9,
        color: textGrey,
      );

      // ── Helper: section box ───────────────────────────────────────────────
      pw.Widget sectionBox({
        required String title,
        required List<pw.Widget> children,
      }) {
        return pw.Container(
          decoration: pw.BoxDecoration(
            color: cardBg,
            borderRadius: pw.BorderRadius.circular(12),
            border: pw.Border.all(color: borderColor, width: 1),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: pw.Row(children: [
                  pw.Container(
                    width: 3,
                    height: 14,
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(title.toUpperCase(),
                      style: styleSectionHeader),
                ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ],
          ),
        );
      }

      // ── Helper: info row ──────────────────────────────────────────────────
      pw.Widget infoRow(String label, String value,
          {bool isLast = false}) {
        return pw.Column(children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 130,
                child: pw.Text(label, style: styleLabel),
              ),
              pw.Expanded(
                child: pw.Text(value, style: styleValue),
              ),
            ],
          ),
          if (!isLast) ...[
            pw.SizedBox(height: 10),
            pw.Container(height: 0.5, color: borderColor),
            pw.SizedBox(height: 10),
          ],
        ]);
      }

      // ── Helper: score bar (Flex-based — no FractionallySizedBox) ─────────
      // FractionallySizedBox removed: crashes when value is 0.0 in pdf pkg
      pw.Widget scoreBar(
          String label, double score, PdfColor barColor) {
        final pct         = (score * 100).toStringAsFixed(1);
        final filled      = (score.clamp(0.0, 1.0) * 1000).round().clamp(1, 1000);
        final empty       = (1000 - filled).clamp(0, 999);

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: 10,
                        color: textWhite)),
                pw.Text('$pct%',
                    style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 10,
                        color: barColor)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.ClipRRect(
              horizontalRadius: 3,
              verticalRadius: 3,
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: filled,
                    child: pw.Container(height: 6, color: barColor),
                  ),
                  if (empty > 0)
                    pw.Expanded(
                      flex: empty,
                      child: pw.Container(height: 6, color: borderColor),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
          ],
        );
      }

      // ── Confidence bar helper (same Flex approach) ────────────────────────
      pw.Widget confBar(double confidence, PdfColor barColor) {
        final filled = (confidence.clamp(0.0, 1.0) * 1000)
            .round()
            .clamp(1, 1000);
        final empty  = (1000 - filled).clamp(0, 999);
        return pw.ClipRRect(
          horizontalRadius: 4,
          verticalRadius: 4,
          child: pw.Row(
            children: [
              pw.Expanded(
                flex: filled,
                child: pw.Container(height: 8, color: barColor),
              ),
              if (empty > 0)
                pw.Expanded(
                  flex: empty,
                  child: pw.Container(height: 8, color: borderColor),
                ),
            ],
          ),
        );
      }

      // ── Build PDF page ────────────────────────────────────────────────────
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (ctx) => [
            // ── HEADER ──────────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.fromLTRB(32, 32, 32, 24),
              color: darkBg,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      // Logo box
                      pw.Container(
                        width: 44,
                        height: 44,
                        decoration: pw.BoxDecoration(
                          gradient: pw.LinearGradient(
                            colors: [primaryColor, accentPurple],
                          ),
                          borderRadius: pw.BorderRadius.circular(10),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Text('L',
                            style: pw.TextStyle(
                                font: pw.Font.helveticaBold(),
                                fontSize: 24,
                                color: textWhite)),
                      ),
                      pw.SizedBox(width: 14),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('LungScan AI', style: styleHeading),
                          pw.Text(
                              'COVID-19 & Lung Disease Detection',
                              style: styleSubtitle),
                        ],
                      ),
                      pw.Spacer(),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('DIAGNOSTIC REPORT',
                              style: pw.TextStyle(
                                  font: pw.Font.helveticaBold(),
                                  fontSize: 11,
                                  color: primaryColor,
                                  letterSpacing: 1.2)),
                          pw.SizedBox(height: 4),
                          pw.Text('$dateStr  |  $timeStr',
                              style: styleSmall),
                          pw.Text(
                              'Report ID: ${_patientIdCtrl.text}',
                              style: styleSmall),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  // ✅ FIXED: was primaryColor.shade(0.4) — now withAlpha()
                  pw.Container(
                      height: 1,
                      color: primaryColor.withAlpha(0.4)),
                ],
              ),
            ),

            // ── BODY ────────────────────────────────────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(32, 24, 32, 32),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [

                  // ── Patient Information ────────────────────────────────
                  sectionBox(
                    title: 'Patient Information',
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Column(children: [
                              infoRow('Patient ID',
                                  _patientIdCtrl.text),
                              infoRow('Full Name',
                                  _nameCtrl.text.trim()),
                              infoRow("Father's Name",
                                  _fatherNameCtrl.text.trim()),
                              infoRow(
                                  'Email',
                                  _emailCtrl.text.trim().isEmpty
                                      ? '—'
                                      : _emailCtrl.text.trim()),
                            ]),
                          ),
                          pw.SizedBox(width: 24),
                          pw.Expanded(
                            child: pw.Column(children: [
                              infoRow('Gender', _selectedGender),
                              infoRow(
                                  'Blood Group', _selectedBloodGroup),
                              infoRow(
                                  'Date of Birth',
                                  _dobCtrl.text.isEmpty
                                      ? '—'
                                      : _dobCtrl.text),
                              infoRow('Age', _calculateAge(),
                                  isLast: true),
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 16),

                  // ── Analysis Result ────────────────────────────────────
                  sectionBox(
                    title: 'Analysis Result',
                    children: result == null
                        ? [
                      pw.Container(
                        alignment: pw.Alignment.center,
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 20),
                        child: pw.Text(
                          'No analysis performed yet.\n'
                              'Please scan a chest X-ray first.',
                          style: pw.TextStyle(
                              font: pw.Font.helvetica(),
                              fontSize: 11,
                              color: textGrey),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ]
                        : [
                      // Diagnosis + confidence row
                      pw.Row(
                        crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                        children: [
                          // Diagnosis box
                          // ✅ FIXED: was severityColor.shade(0.1/.4)
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(16),
                              decoration: pw.BoxDecoration(
                                color: severityColor.withAlpha(0.1),
                                borderRadius:
                                pw.BorderRadius.circular(10),
                                border: pw.Border.all(
                                    color: severityColor.withAlpha(0.4),
                                    width: 1),
                              ),
                              child: pw.Column(
                                crossAxisAlignment:
                                pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('DIAGNOSIS',
                                      style: pw.TextStyle(
                                          font: pw.Font.helveticaBold(),
                                          fontSize: 8,
                                          color: severityColor,
                                          letterSpacing: 1.2)),
                                  pw.SizedBox(height: 6),
                                  pw.Text(result.label,
                                      style: pw.TextStyle(
                                          font: pw.Font.helveticaBold(),
                                          fontSize: 20,
                                          color: severityColor)),
                                  pw.SizedBox(height: 6),
                                  pw.Text(severityLbl,
                                      style: pw.TextStyle(
                                          font: pw.Font.helvetica(),
                                          fontSize: 10,
                                          color: textGrey)),
                                ],
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 16),
                          // Confidence box
                          pw.Container(
                            padding: const pw.EdgeInsets.all(16),
                            decoration: pw.BoxDecoration(
                              color: cardBg,
                              borderRadius:
                              pw.BorderRadius.circular(10),
                              border: pw.Border.all(
                                  color: borderColor, width: 1),
                            ),
                            child: pw.Column(
                              children: [
                                pw.Text(
                                  '${(result.confidence * 100).toStringAsFixed(1)}%',
                                  style: pw.TextStyle(
                                      font: pw.Font.helveticaBold(),
                                      fontSize: 28,
                                      color: severityColor),
                                ),
                                pw.Text('Confidence',
                                    style: styleSmall),
                                pw.SizedBox(height: 8),
                                // ✅ FIXED: removed result.inferenceTimeMs
                                // (field doesn't exist on ClassificationResult)
                                pw.Text('EfficientNetB0',
                                    style: pw.TextStyle(
                                        font: pw.Font.helveticaBold(),
                                        fontSize: 11,
                                        color: primaryColor)),
                                pw.Text('Model',
                                    style: styleSmall),
                              ],
                            ),
                          ),
                        ],
                      ),

                      pw.SizedBox(height: 18),

                      // Confidence bar
                      pw.Text('Confidence Score',
                          style: pw.TextStyle(
                              font: pw.Font.helvetica(),
                              fontSize: 9,
                              color: textGrey)),
                      pw.SizedBox(height: 6),
                      confBar(result.confidence, severityColor),

                      pw.SizedBox(height: 20),

                      // Score breakdown
                      pw.Text('CLASS PROBABILITY BREAKDOWN',
                          style: styleSectionHeader),
                      pw.SizedBox(height: 12),
                      ...result.allScores.entries.map((e) {
                        PdfColor barC;
                        switch (e.key.toLowerCase()) {
                          case 'covid':
                            barC = red;
                            break;
                          case 'normal':
                            barC = green;
                            break;
                          case 'lung opacity':
                            barC = orange;
                            break;
                          default:
                            barC = yellow;
                        }
                        return scoreBar(e.key, e.value, barC);
                      }),

                      pw.SizedBox(height: 8),

                      // Clinical note
                      pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          // ✅ FIXED: was severityColor.shade(0.06/.25)
                          color: severityColor.withAlpha(0.06),
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(
                              color: severityColor.withAlpha(0.25),
                              width: 0.5),
                        ),
                        child: pw.Row(
                          crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                          children: [
                            pw.Container(
                              width: 3,
                              height: 48,
                              decoration: pw.BoxDecoration(
                                color: severityColor,
                                borderRadius:
                                pw.BorderRadius.circular(2),
                              ),
                            ),
                            pw.SizedBox(width: 10),
                            pw.Expanded(
                              child: pw.Column(
                                crossAxisAlignment:
                                pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                      'CLINICAL INTERPRETATION',
                                      style: pw.TextStyle(
                                          font: pw.Font.helveticaBold(),
                                          fontSize: 8,
                                          color: severityColor,
                                          letterSpacing: 0.8)),
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    _clinicalNote(result.label),
                                    style: pw.TextStyle(
                                        font: pw.Font.helvetica(),
                                        fontSize: 9,
                                        color: textGrey,
                                        lineSpacing: 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 16),

                  // ── Scan Information ───────────────────────────────────
                  if (widget.latestRecord != null)
                    sectionBox(
                      title: 'Scan Information',
                      children: [
                        infoRow(
                            'Scan Date',
                            DateFormat('dd MMM yyyy – HH:mm')
                                .format(widget.latestRecord!.timestamp)),
                        infoRow('AI Model',
                            'EfficientNetB0 (TFLite float32)'),
                        infoRow('Input Resolution', '224 × 224 px'),
                        infoRow('Classes',
                            'COVID, Lung Opacity, Normal, Viral Pneumonia'),
                        infoRow(
                            'Preprocessing',
                            'Resize → Normalise (div 127.5 - 1.0) → float32',
                            isLast: true),
                      ],
                    ),

                  pw.SizedBox(height: 16),

                  // ── Disclaimer ─────────────────────────────────────────
                  pw.Container(
                    padding: const pw.EdgeInsets.all(14),
                    decoration: pw.BoxDecoration(
                      color: warningBg,
                      borderRadius: pw.BorderRadius.circular(10),
                      border:
                      pw.Border.all(color: warningBorder, width: 1),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('!',
                            style: pw.TextStyle(
                                font: pw.Font.helveticaBold(),
                                fontSize: 14,
                                color: warningText)),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment:
                            pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('MEDICAL DISCLAIMER',
                                  style: pw.TextStyle(
                                      font: pw.Font.helveticaBold(),
                                      fontSize: 9,
                                      color: warningText,
                                      letterSpacing: 1.0)),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'This report is generated for research and educational '
                                    'purposes only. It is NOT a medical diagnosis and must '
                                    'NOT be used as a basis for clinical decisions. Always '
                                    'consult a qualified healthcare professional.',
                                style: pw.TextStyle(
                                    font: pw.Font.helvetica(),
                                    fontSize: 9,
                                    color: warningBody,
                                    lineSpacing: 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 24),

                  // ── Footer ─────────────────────────────────────────────
                  pw.Container(height: 1, color: borderColor),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                          '© ${DateTime.now().year} LungScan AI  ·  v1.0.0',
                          style: styleSmall),
                      pw.Text('Generated: $dateStr at $timeStr',
                          style: styleSmall),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      // ── Save PDF ──────────────────────────────────────────────────────────
      final dir      = await getApplicationDocumentsDirectory();
      final fileName =
          'LungScan_${_patientIdCtrl.text}_'
          '${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showSuccessSheet(file.path);
    } catch (e, st) {
      debugPrint('PDF generation error: $e\n$st');
      if (mounted) {
        setState(() => _isGenerating = false);
        _showSnack('PDF generation failed: $e');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Success bottom sheet
  // ─────────────────────────────────────────────────────────────────────────────
  void _showSuccessSheet(String filePath) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0C1828),
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF2ECC71).withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF2ECC71).withOpacity(0.4)),
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: Color(0xFF2ECC71), size: 32),
            )
                .animate()
                .scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text('Report Generated!',
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 6),
            Text('PDF saved to your device',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.white54)),
            const SizedBox(height: 4),
            Text(
              filePath.split('/').last,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 28),
            // Open button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  OpenFilex.open(filePath);
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('Open Report',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Share button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.shareXFiles(
                    [XFile(filePath)],
                    subject: 'LungScan AI Diagnostic Report',
                  );
                },
                icon: const Icon(Icons.share_rounded,
                    color: Colors.white70, size: 18),
                label: Text('Share',
                    style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1A2E45)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Done',
                  style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: AppTheme.colorCritical.withOpacity(0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ───────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
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
                      top: -20, right: -20,
                      child: Container(
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary.withOpacity(0.06),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20, left: 20, right: 20,
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFF00D4FF),
                              Color(0xFF7B2FFF),
                            ]),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                              Icons.description_outlined,
                              color: Colors.white,
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text('Get Report',
                                style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.5)),
                            Text('Generate PDF diagnostic report',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white38)),
                          ],
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Form ──────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),

                // Analysis status banner
                _buildAnalysisBanner(),
                const SizedBox(height: 20),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _SectionLabel('Patient ID'),
                      const SizedBox(height: 8),
                      _buildPatientIdField(),
                      const SizedBox(height: 20),

                      _SectionLabel("Patient's Full Name *"),
                      const SizedBox(height: 8),
                      _buildTextFormField(
                        controller: _nameCtrl,
                        hint: 'Enter full name',
                        icon: Icons.person_outline_rounded,
                        validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 20),

                      _SectionLabel("Father's Name *"),
                      const SizedBox(height: 8),
                      _buildTextFormField(
                        controller: _fatherNameCtrl,
                        hint: "Enter father's name",
                        icon: Icons.people_outline_rounded,
                        validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? "Father's name is required"
                            : null,
                      ),
                      const SizedBox(height: 20),

                      _SectionLabel('Email (Optional)'),
                      const SizedBox(height: 8),
                      _buildTextFormField(
                        controller: _emailCtrl,
                        hint: 'patient@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return null;
                          final re = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                          return re.hasMatch(v.trim())
                              ? null
                              : 'Invalid email format';
                        },
                      ),
                      const SizedBox(height: 20),

                      // Gender + Blood Group
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                _SectionLabel('Gender *'),
                                const SizedBox(height: 8),
                                _buildDropdownField<String>(
                                  value: _selectedGender,
                                  items: _genders,
                                  icon: Icons.wc_outlined,
                                  onChanged: (v) => setState(
                                          () => _selectedGender = v!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                _SectionLabel('Blood Group *'),
                                const SizedBox(height: 8),
                                _buildDropdownField<String>(
                                  value: _selectedBloodGroup,
                                  items: _bloodGroups,
                                  icon: Icons.bloodtype_outlined,
                                  onChanged: (v) => setState(() =>
                                  _selectedBloodGroup = v!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _SectionLabel('Date of Birth *'),
                      const SizedBox(height: 8),
                      _buildDOBField(),
                      const SizedBox(height: 36),

                      _buildGenerateButton(),
                      const SizedBox(height: 12),

                      // Disclaimer
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.amber.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.amber, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This PDF is for research purposes only. '
                                    'Not a substitute for medical advice.',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.amber.shade200,
                                    height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Form sub-widgets
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildAnalysisBanner() {
    final hasResult = widget.latestRecord != null;
    final color = hasResult ? const Color(0xFF2ECC71) : Colors.amber;
    final icon  = hasResult
        ? Icons.check_circle_outline
        : Icons.warning_amber_rounded;
    final title    = hasResult
        ? 'Analysis result included'
        : 'No analysis result yet';
    final subtitle = hasResult
        ? '${widget.latestRecord!.result.label}  ·  '
        '${(widget.latestRecord!.result.confidence * 100).toStringAsFixed(1)}% confidence'
        : 'Scan a chest X-ray first for a complete report';

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 11, color: Colors.white54)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildPatientIdField() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A2E45)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.badge_outlined,
              color: Color(0xFF4A6580), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _patientIdCtrl,
              readOnly: true,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Auto-generated',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF4A6580)),
                contentPadding:
                const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          IconButton(
            onPressed: _regenerateId,
            icon: const Icon(Icons.refresh_rounded,
                color: AppTheme.primary, size: 20),
            tooltip: 'Regenerate ID',
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            fontSize: 14, color: const Color(0xFF4A6580)),
        prefixIcon:
        Icon(icon, color: const Color(0xFF4A6580), size: 20),
        filled: true,
        fillColor: AppTheme.cardBg,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFF1A2E45)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFF1A2E45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: AppTheme.primary.withOpacity(0.6),
              width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: AppTheme.colorCritical.withOpacity(0.6),
              width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          BorderSide(color: AppTheme.colorCritical, width: 1.5),
        ),
        errorStyle: GoogleFonts.inter(
            fontSize: 11, color: AppTheme.colorCritical),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required T value,
    required List<T> items,
    required IconData icon,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A2E45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF4A6580), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: const Color(0xFF0F1F33),
                icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF6B8CAE)),
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.white),
                onChanged: onChanged,
                items: items
                    .map((g) => DropdownMenuItem<T>(
                    value: g,
                    child: Text(g.toString())))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDOBField() {
    return GestureDetector(
      onTap: _pickDOB,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1A2E45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined,
                color: Color(0xFF4A6580), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _dobCtrl.text.isEmpty
                    ? 'Select date of birth'
                    : _dobCtrl.text,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _dobCtrl.text.isEmpty
                        ? const Color(0xFF4A6580)
                        : Colors.white),
              ),
            ),
            if (_selectedDOB != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _calculateAge(),
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.calendar_today_outlined,
                color: Color(0xFF4A6580), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return GestureDetector(
      onTap: _isGenerating ? null : _generateReport,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          gradient: _isGenerating
              ? null
              : const LinearGradient(
            colors: [Color(0xFF00897B), Color(0xFF00897B)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          color: _isGenerating ? const Color(0xFF1A2E45) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isGenerating
              ? []
              : [
            BoxShadow(
                color: AppTheme.primary.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _isGenerating
              ? [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white54)),
            const SizedBox(width: 12),
            Text('Generating PDF...',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white54)),
          ]
              : [
            const Icon(Icons.picture_as_pdf_outlined,
                color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text('Generate PDF Report',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(
        begin: 0.2,
        end: 0,
        duration: 300.ms,
        curve: Curves.easeOut);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

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
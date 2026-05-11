import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Result of a single classification inference
class ClassificationResult {
  final String label;
  final double confidence;
  final Map<String, double> allScores;
  final int inferenceTimeMs;

  const ClassificationResult({
    required this.label,
    required this.confidence,
    required this.allScores,
    required this.inferenceTimeMs,
  });
}

/// Severity / urgency levels per class
enum Severity { normal, moderate, high, critical }

/// Lung Disease Classifier wrapping the EfficientNetB0 TFLite model
class LungDiseaseClassifier {
  // ── Model constants (must match notebook config) ────────────────────────────
  static const int inputSize = 224;
  static const String modelAsset = 'assets/model/covid_classifier_float32.tflite';
  static const List<String> classNames = [
    'COVID',
    'Lung Opacity',
    'Normal',
    'Viral Pneumonia',
  ];

  // Severity mapping for each class
  static const Map<String, Severity> classSeverity = {
    'COVID': Severity.critical,
    'Lung Opacity': Severity.high,
    'Normal': Severity.normal,
    'Viral Pneumonia': Severity.moderate,
  };

  // ── Private state ────────────────────────────────────────────────────────────
  Interpreter? _interpreter;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  /// Initialize the TFLite interpreter from the bundled asset.
  Future<void> loadModel() async {
    try {
      debugPrint('╔══════════════════════════════════════════');
      debugPrint('║  LungScan: Starting model initialization');
      debugPrint('╠══════════════════════════════════════════');
      debugPrint('║  Asset path : $modelAsset');

      // ── Step 1: Verify asset exists in bundle ──────────────────────────────
      debugPrint('║  Step 1/3  : Verifying asset exists...');
      try {
        final data = await rootBundle.load(modelAsset);
        final sizeKB = (data.lengthInBytes / 1024).toStringAsFixed(1);
        debugPrint('║  ✅ Asset found — size: ${sizeKB} KB');

        // If size is suspiciously small the file was compressed/corrupted
        if (data.lengthInBytes < 100 * 1024) {
          debugPrint('║  ⚠️  WARNING: File is very small (${sizeKB} KB).');
          debugPrint('║     Add androidResources { noCompress += ["tflite"] }');
          debugPrint('║     to android/app/build.gradle.kts and flutter clean');
        }
      } catch (assetError) {
        debugPrint('║  ❌ Asset NOT found in bundle!');
        debugPrint('║     Error: $assetError');
        debugPrint('║  FIX: Check pubspec.yaml assets section and run:');
        debugPrint('║       flutter clean && flutter pub get');
        rethrow;
      }

      // ── Step 2: Create interpreter ─────────────────────────────────────────
      debugPrint('║  Step 2/3  : Creating TFLite interpreter...');
      final interpreterOptions = InterpreterOptions()..threads = 4;

      _interpreter = await Interpreter.fromAsset(
        modelAsset,
        options: interpreterOptions,
      );
      debugPrint('║  ✅ Interpreter created');

      // ── Step 3: Validate tensor shapes ────────────────────────────────────
      debugPrint('║  Step 3/3  : Validating tensor shapes...');
      final inputShape  = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final inputType   = _interpreter!.getInputTensor(0).type;
      final outputType  = _interpreter!.getOutputTensor(0).type;

      debugPrint('║  Input  shape : $inputShape  type: $inputType');
      debugPrint('║  Output shape : $outputShape  type: $outputType');

      // Sanity checks
      final inputOk  = inputShape.length == 4 &&
          inputShape[1] == inputSize &&
          inputShape[2] == inputSize &&
          inputShape[3] == 3;
      final outputOk = outputShape.length == 2 &&
          outputShape[1] == classNames.length;

      if (!inputOk) {
        debugPrint('║  ❌ Unexpected input shape: $inputShape');
        debugPrint('║     Expected: [1, $inputSize, $inputSize, 3]');
        throw StateError('Model input shape mismatch: $inputShape');
      }
      if (!outputOk) {
        debugPrint('║  ❌ Unexpected output shape: $outputShape');
        debugPrint('║     Expected: [1, ${classNames.length}]');
        throw StateError('Model output shape mismatch: $outputShape');
      }

      _isLoaded = true;

      debugPrint('╠══════════════════════════════════════════');
      debugPrint('║  ✅ Model ready — all checks passed');
      debugPrint('╚══════════════════════════════════════════');
    } catch (e, stack) {
      _isLoaded = false;
      debugPrint('╠══════════════════════════════════════════');
      debugPrint('║  ❌ Model load FAILED');
      debugPrint('║  Error : $e');
      debugPrint('║  Stack : $stack');
      debugPrint('╚══════════════════════════════════════════');
      rethrow;
    }
  }

  /// Release interpreter resources.
  void dispose() {
    _interpreter?.close();
    _isLoaded = false;
    debugPrint('LungScan: Interpreter disposed');
  }

  // ── Inference ────────────────────────────────────────────────────────────────

  /// Run classification on a [File] (JPEG / PNG).
  Future<ClassificationResult> classifyFile(File imageFile) async {
    debugPrint('LungScan: classifyFile → ${imageFile.path}');
    final bytes = await imageFile.readAsBytes();
    return classifyBytes(bytes);
  }

  /// Run classification on raw image bytes.
  Future<ClassificationResult> classifyBytes(Uint8List imageBytes) async {
    if (!_isLoaded || _interpreter == null) {
      throw StateError('Model is not loaded. Call loadModel() first.');
    }

    final stopwatch = Stopwatch()..start();

    // 1. Decode → resize to 224×224
    debugPrint('LungScan: Decoding image (${imageBytes.length} bytes)...');
    final rawImage = img.decodeImage(imageBytes);
    if (rawImage == null) throw ArgumentError('Cannot decode image bytes.');

    debugPrint('LungScan: Original size: ${rawImage.width}×${rawImage.height}');

    final resized = img.copyResize(
      rawImage,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );
    debugPrint('LungScan: Resized to $inputSize×$inputSize');

    // 2. Apply EfficientNet preprocess_input → pixel ∈ [-1, 1]
    //    (pixel / 127.5) - 1.0
    final input = _buildInputTensor(resized);
    debugPrint('LungScan: Input tensor built');

    // 3. Run inference
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final outputBuffer = List.generate(
      outputShape[0],
          (_) => List<double>.filled(outputShape[1], 0.0),
    );

    debugPrint('LungScan: Running inference...');
    _interpreter!.run(input, outputBuffer);
    stopwatch.stop();
    debugPrint('LungScan: Inference complete in ${stopwatch.elapsedMilliseconds}ms');

    // 4. Parse softmax scores
    final scores = List<double>.from(outputBuffer[0]);
    final allScores = <String, double>{};
    for (int i = 0; i < classNames.length; i++) {
      allScores[classNames[i]] = scores[i];
      debugPrint('LungScan:   ${classNames[i]}: ${(scores[i]*100).toStringAsFixed(2)}%');
    }

    // 5. Pick argmax
    int maxIdx = 0;
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > scores[maxIdx]) maxIdx = i;
    }

    final result = ClassificationResult(
      label: classNames[maxIdx],
      confidence: scores[maxIdx],
      allScores: allScores,
      inferenceTimeMs: stopwatch.elapsedMilliseconds,
    );

    debugPrint('LungScan: ✅ Result → ${result.label} '
        '(${(result.confidence * 100).toStringAsFixed(1)}%)');

    return result;
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Convert [img.Image] to [1, 224, 224, 3] float tensor
  /// with EfficientNet preprocess_input: (pixel / 127.5) - 1.0
  List<List<List<List<double>>>> _buildInputTensor(img.Image image) {
    return List.generate(
      1,
          (_) => List.generate(
        inputSize,
            (y) => List.generate(
          inputSize,
              (x) {
            final pixel = image.getPixel(x, y);
            return [
              (pixel.r / 127.5) - 1.0,
              (pixel.g / 127.5) - 1.0,
              (pixel.b / 127.5) - 1.0,
            ];
          },
        ),
      ),
    );
  }

  // ── Utilities ────────────────────────────────────────────────────────────────

  static Severity getSeverity(String label) =>
      classSeverity[label] ?? Severity.normal;

  static String getSeverityLabel(Severity severity) {
    switch (severity) {
      case Severity.normal:
        return 'Normal — No disease detected';
      case Severity.moderate:
        return 'Moderate — Consult a doctor';
      case Severity.high:
        return 'High — Seek medical attention';
      case Severity.critical:
        return 'Critical — Urgent care required';
    }
  }
}
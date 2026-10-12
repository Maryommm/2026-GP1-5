import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';

/// Scan a sick leaf: live camera inside a viewfinder, tips, and a shutter.
/// Taking the photo freezes the frame, shows a short "analysing" sweep and
/// then the diagnosis dialog.
///
/// UI only for now: the photo isn't saved or sent anywhere, and the result
/// is always the same prototype diagnosis.
/// TODO(diagnosis-model): Capture the photo, send it to the diagnosis model
///   and show its real result.
class LeafScanScreen extends StatefulWidget {
  const LeafScanScreen({super.key});

  @override
  State<LeafScanScreen> createState() => _LeafScanScreenState();
}

/// What the diagnosis dialog's buttons ask the screen to do.
enum _ResultAction { scanAgain, home }

class _LeafScanScreenState extends State<LeafScanScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  bool _starting = false;
  bool _cameraFailed = false;

  /// True when the camera was closed because the app went to the background,
  /// so it's reopened when the app comes back.
  bool _closedForBackground = false;

  bool _analysing = false;
  int _step = 0;
  Timer? _stepTimer;
  Timer? _doneTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepTimer?.cancel();
    _doneTimer?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera has to be released while the app is in the background.
    final camera = _camera;
    if (state == AppLifecycleState.inactive && camera != null) {
      setState(() => _camera = null);
      _closedForBackground = true;
      camera.dispose();
    } else if (state == AppLifecycleState.resumed && _closedForBackground) {
      _closedForBackground = false;
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    if (_starting) return;
    _starting = true;
    setState(() => _cameraFailed = false);
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final camera = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await camera.initialize();
      if (!mounted) {
        await camera.dispose();
        return;
      }
      if (_analysing) await camera.pausePreview();
      setState(() => _camera = camera);
    } catch (_) {
      // No camera (desktop, web), or the user said no to camera access.
      // The placeholder still lets the rest of the flow be tried.
      if (mounted) setState(() => _cameraFailed = true);
    } finally {
      _starting = false;
    }
  }

  void _capture() {
    if (_analysing) return;
    HapticFeedback.mediumImpact();
    // Freezing the preview looks like the photo was taken.
    _camera?.pausePreview().catchError((_) {});
    setState(() {
      _analysing = true;
      _step = 0;
    });
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1000), (t) {
      if (_step >= 2) return t.cancel();
      setState(() => _step++);
    });
    _doneTimer = Timer(const Duration(milliseconds: 3200), _showResult);
  }

  Future<void> _showResult() async {
    if (!mounted) return;
    final action = await showDialog<_ResultAction>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => const _DiagnosisDialog(),
    );
    if (!mounted) return;
    if (action == _ResultAction.home) {
      Navigator.of(context).pop();
      return;
    }
    // "Scan another leaf", or the dialog was closed: back to the camera.
    _stepTimer?.cancel();
    _camera?.resumePreview().catchError((_) {});
    setState(() => _analysing = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: LeafPrintBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(title: s.scanTitle, accent: s.scanAccent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 0.85,
                      child: Entrance(
                        delay: const Duration(milliseconds: 100),
                        child: _Viewfinder(
                          camera: _camera,
                          failed: _cameraFailed,
                          analysing: _analysing,
                          onRetry: _startCamera,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Both bottom panels share one slot (the taller one sets its
              // height), so the viewfinder doesn't jump when they swap.
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Entrance(
                  delay: const Duration(milliseconds: 180),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _Swap(
                        visible: !_analysing,
                        child: _AimControls(onCapture: _capture),
                      ),
                      _Swap(
                        visible: _analysing,
                        child: _AnalysingStatus(
                          text: s.scanAnalysingSteps[_step],
                          stepKey: _step,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Back + title on one row, the hand-written line under it.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.accent});
  final String title;
  final String accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EthmarBackButton(tooltip: S.of(context).back),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(context).copyWith(fontSize: 26),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16),
            child: Entrance(
              child: Text(accent, style: AppText.accent(context, size: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades one of the two bottom panels in or out. The hidden one can't be
/// tapped or read by screen readers.
class _Swap extends StatelessWidget {
  const _Swap({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Viewfinder: white card holding the camera (or a placeholder), the corner
// brackets, and the scanning sweep while analysing.
// ---------------------------------------------------------------------------

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.camera,
    required this.failed,
    required this.analysing,
    required this.onRetry,
  });
  final CameraController? camera;
  final bool failed;
  final bool analysing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final live = camera != null && camera!.value.isInitialized;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (live)
              _CameraFill(camera: camera!)
            else
              _NoCamera(failed: failed, onRetry: onRetry),
            AnimatedOpacity(
              opacity: analysing ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: const ColoredBox(color: Color(0x40152C14)),
            ),
            IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: CustomPaint(
                  painter: _CornerBrackets(
                    live || analysing ? Colors.white : AppColors.forest,
                  ),
                ),
              ),
            ),
            if (analysing) const _ScanSweep(),
          ],
        ),
      ),
    );
  }
}

/// The camera preview filling the viewfinder (cropped, not stretched).
class _CameraFill extends StatelessWidget {
  const _CameraFill({required this.camera});
  final CameraController camera;

  @override
  Widget build(BuildContext context) {
    // The preview size is reported in landscape; the phone is upright.
    final size = camera.value.previewSize!;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: CameraPreview(camera),
      ),
    );
  }
}

/// Shown while the camera starts, or when there isn't one.
class _NoCamera extends StatelessWidget {
  const _NoCamera({required this.failed, required this.onRetry});
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ColoredBox(
      color: AppColors.forestTint,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: 0.55,
                child: Image.asset(
                  'assets/images/ethmar_leaf_light_flat.png',
                  height: 110,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.eco_rounded,
                    size: 90,
                    color: AppColors.forest,
                  ),
                ),
              ),
              if (failed) ...[
                const SizedBox(height: 16),
                Text(
                  s.scanNoCamera,
                  textAlign: TextAlign.center,
                  style: AppText.small(context, color: AppColors.forest),
                ),
                EthmarLink(label: s.tryAgain, onTap: onRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Four rounded "L" corners, like the sketch's frame.
class _CornerBrackets extends CustomPainter {
  const _CornerBrackets(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const len = 36.0, r = 14.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final corner = Path()
      ..moveTo(0, len)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(len, 0);
    // Draw the top-left corner, then mirror it into the other three.
    for (final (sx, sy) in const [(1.0, 1.0), (-1.0, 1.0), (1.0, -1.0), (-1.0, -1.0)]) {
      canvas
        ..save()
        ..translate(sx > 0 ? 0 : size.width, sy > 0 ? 0 : size.height)
        ..scale(sx, sy)
        ..drawPath(corner, paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CornerBrackets old) => old.color != color;
}

/// A turquoise line sweeping up and down over the frozen photo.
class _ScanSweep extends StatefulWidget {
  const _ScanSweep();

  @override
  State<_ScanSweep> createState() => _ScanSweepState();
}

class _ScanSweepState extends State<_ScanSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final v = Curves.easeInOut.transform(_c.value);
          return Align(alignment: Alignment(0, -0.9 + 1.8 * v), child: child);
        },
        child: Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.seaTint,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppColors.sea.withValues(alpha: 0.9),
                blurRadius: 14,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom panels: tips + shutter while aiming, status text while analysing.
// ---------------------------------------------------------------------------

class _AimControls extends StatelessWidget {
  const _AimControls({required this.onCapture});
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.scanTipsTitle, style: AppText.small(context)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _TipChip(icon: Icons.wb_sunny_outlined, label: s.scanTipLight),
            _TipChip(icon: Icons.eco_outlined, label: s.scanTipOneLeaf),
            _TipChip(icon: Icons.pan_tool_outlined, label: s.scanTipStill),
          ],
        ),
        const SizedBox(height: 20),
        _ShutterButton(label: s.scanCapture, onPressed: onCapture),
      ],
    );
  }
}

class _TipChip extends StatelessWidget {
  const _TipChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 12, 7),
      decoration: BoxDecoration(
        color: AppColors.forestTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.forest),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.small(context, color: AppColors.forest)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Round forest shutter with a white ring, like a camera button.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.forest.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: AppColors.forest,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              splashColor: const Color(0x33FFFFFF),
              child: const SizedBox.square(
                dimension: 72,
                child: Icon(
                  Icons.photo_camera_rounded,
                  size: 32,
                  color: AppColors.onForest,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnalysingStatus extends StatelessWidget {
  const _AnalysingStatus({required this.text, required this.stepKey});
  final String text;
  final int stepKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              text,
              key: ValueKey(stepKey),
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const LinearProgressIndicator(
              minHeight: 6,
              color: AppColors.sea,
              backgroundColor: AppColors.seaTint,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Diagnosis dialog (prototype result, always "Dry leaves").
// TODO(diagnosis-model): Fill this from the model's result (name, how hard
//   it is to fix and description).
// ---------------------------------------------------------------------------

class _DiagnosisDialog extends StatelessWidget {
  const _DiagnosisDialog();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AppColors.sunTint,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/ethmar_leaf_curled.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.eco_rounded,
                    size: 40,
                    color: AppColors.sunDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              s.diagDryLeavesName,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 26),
            ),
            const SizedBox(height: 2),
            Text(
              s.diagEasyToFix,
              textAlign: TextAlign.center,
              style: AppText.label(context, color: AppColors.success)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              s.diagDryLeavesBody,
              textAlign: TextAlign.center,
              style: AppText.body(context),
            ),
            const SizedBox(height: 24),
            EthmarButton(
              label: s.scanAnother,
              onPressed: () =>
                  Navigator.of(context).pop(_ResultAction.scanAgain),
            ),
            const SizedBox(height: 4),
            Center(
              child: EthmarLink(
                label: s.backToHome,
                onTap: () => Navigator.of(context).pop(_ResultAction.home),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

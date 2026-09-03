/// QR scan flow for new MFA entries with a framed scanner overlay.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/features/mfa/domain/otpauth_uri.dart';
import 'package:nucleus/features/mfa/presentation/providers/mfa_list_provider.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/shared/widgets/app_icon.dart';
import 'package:nucleus/shared/widgets/vault_loader.dart';

class MfaScanPage extends ConsumerStatefulWidget {
  const MfaScanPage({super.key});

  @override
  ConsumerState<MfaScanPage> createState() => _MfaScanPageState();
}

class _MfaScanPageState extends ConsumerState<MfaScanPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _handled = false;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled || _saving) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    final parsed = raw != null ? OtpAuthUri.tryParse(raw) : null;
    if (parsed == null) return;

    _handled = true;
    setState(() => _saving = true);

    final session = ref.read(vaultSessionProvider);
    final userId = ref.read(authRepositoryProvider).currentUserId;
    final dek = session.dek;
    if (dek == null || userId == null) {
      _handled = false;
      if (mounted) setState(() => _saving = false);
      return;
    }

    try {
      await ref.read(mfaRepositoryProvider).createEntry(
            userId: userId,
            dek: dek,
            secret: parsed.secret,
            issuer: parsed.issuer,
            accountName: parsed.accountName,
          );
      await ref.read(mfaListProvider.notifier).refresh();
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      final message = await userFacingErrorMessage(
        ref.read(connectivityServiceProvider),
        e,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      _handled = false;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _saving ? null : () => context.pop(),
          icon: AppIcon('back', color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Flash',
            onPressed: _saving ? null : () => _controller.toggleTorch(),
            icon: AppIcon('flash', color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          const _ScannerDimOverlay(),
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: scale.lg),
                  child: Text(
                    'Align the authenticator QR code within the frame',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: scale.fontMd,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: scale.xl),
                Padding(
                  padding: EdgeInsets.fromLTRB(scale.lg, 0, scale.lg, scale.lg),
                  child: Text(
                    'Codes for other websites are stored in your vault and synced when online.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: scale.fontSm,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_saving)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.45),
              child: const Center(child: VaultLoader()),
            ),
        ],
      ),
    );
  }
}

/// Darkens the camera feed outside the scan window and draws corner brackets.
class _ScannerDimOverlay extends StatelessWidget {
  const _ScannerDimOverlay();

  static const _cutoutSize = 260.0;
  static const _cornerLen = 28.0;
  static const _cornerStroke = 4.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(
          constraints.maxWidth / 2,
          constraints.maxHeight * 0.42,
        );
        final cutout = Rect.fromCenter(
          center: center,
          width: _cutoutSize,
          height: _cutoutSize,
        );
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _ScannerOverlayPainter(cutout: cutout),
        );
      },
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter({required this.cutout});

  final Rect cutout;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(cutout, const Radius.circular(20)));
    final dim = Path.combine(PathOperation.difference, overlay, hole);
    canvas.drawPath(
      dim,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final corner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ScannerDimOverlay._cornerStroke
      ..strokeCap = StrokeCap.round;

    final t = cutout.top;
    final b = cutout.bottom;
    final l = cutout.left;
    final right = cutout.right;
    final len = _ScannerDimOverlay._cornerLen;

    canvas.drawLine(Offset(l, t + len), Offset(l, t), corner);
    canvas.drawLine(Offset(l, t), Offset(l + len, t), corner);
    canvas.drawLine(Offset(right - len, t), Offset(right, t), corner);
    canvas.drawLine(Offset(right, t), Offset(right, t + len), corner);
    canvas.drawLine(Offset(l, b - len), Offset(l, b), corner);
    canvas.drawLine(Offset(l, b), Offset(l + len, b), corner);
    canvas.drawLine(Offset(right - len, b), Offset(right, b), corner);
    canvas.drawLine(Offset(right, b), Offset(right, b - len), corner);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.cutout != cutout;
}

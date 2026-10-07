import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../core/navigation/app_page_route.dart';
import '../core/navigation/auth_reveal.dart';
import '../l10n/strings.dart';
import '../nfc/nfc_uid.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import 'payment_success_screen.dart';

class NfcScannerScreen extends StatefulWidget {
  const NfcScannerScreen({
    super.key,
    required this.amount,
    this.idempotencyKey,
  });

  final int amount;
  final String? idempotencyKey;

  @override
  State<NfcScannerScreen> createState() => _NfcScannerScreenState();
}

class _NfcScannerScreenState extends State<NfcScannerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool found = false;
  bool resolving = false;
  bool navigated = false;
  late final String _fareKey = widget.idempotencyKey ?? newIdempotencyKey();

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    stopNfc();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    if (!await nfcEnabled() || !mounted) return;
    await NfcManagerSession.start((uid) {
      if (!mounted || found || resolving || navigated) return;
      _pay(nfcUid: uid);
    });
  }

  Future<void> _goResult({
    required bool success,
    required String passengerName,
    String reference = '',
    VoidCallback? onRetry,
  }) async {
    if (!mounted || navigated) return;
    navigated = true;
    try {
      await stopNfc();
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    await Navigator.pushReplacement(
      context,
      SoftFadeRoute(
        builder: (_) => PaymentSuccessScreen(
          amount: widget.amount,
          passengerName: passengerName,
          reference: reference,
          success: success,
          onRetry: onRetry,
        ),
      ),
    );
  }

  Future<void> _pay({String? serialNumber, String? nfcUid}) async {
    if (resolving || navigated) return;
    resolving = true;
    if (mounted) setState(() => found = true);

    final app = AppScope.of(context);
    final token = app.authToken ?? '';

    try {
      final result = await ApiService.tapPay(
        token: token,
        amount: widget.amount,
        idempotencyKey: _fareKey,
        serialNumber: serialNumber,
        nfcUid: nfcUid,
      );

      final customer = result['customer'] as Map<String, dynamic>? ?? {};
      var name =
          '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'.trim().toUpperCase();
      if (name.isEmpty) {
        name = (result['passenger'] ?? '').toString();
      }
      final reference = (result['reference'] ?? '').toString();

      // Show success first — never block success UI on ledger refresh / NFC stop.
      await _goResult(
        success: true,
        passengerName: name.isEmpty ? 'Passenger' : name,
        reference: reference,
      );

      // Refresh balance quietly after the success screen is up.
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        app.refreshLedger(history: false);
      });
    } catch (e) {
      if (!mounted || navigated) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      await _goResult(
        success: false,
        passengerName: message,
        onRetry: () {
          Navigator.pushReplacement(
            context,
            AppPageRoute(
              builder: (_) => NfcScannerScreen(
                amount: widget.amount,
                idempotencyKey: _fareKey,
              ),
            ),
          );
        },
      );
    } finally {
      resolving = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S(AppScope.of(context).language);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(s.lipia)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 220,
                height: 220,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _PulsePainter(
                        progress: _pulse.value,
                        color: found
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                      ),
                      child: child,
                    );
                  },
                  child: Icon(
                    found ? Icons.check_circle : Icons.contactless,
                    size: 84,
                    color: found
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                found ? s.cardFound : s.bringCard,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                found ? s.scanning : s.nfcHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
              const SizedBox(height: 28),
              Text(
                s.tzs(widget.amount),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NfcManagerSession {
  static Future<void> start(void Function(String uid) onUid) async {
    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443},
      onDiscovered: (tag) {
        final uid = uidFromTag(tag);
        if (uid != null) onUid(uid);
      },
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final radius = 40 + t * 70;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color.withValues(alpha: (1 - t) * 0.45);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

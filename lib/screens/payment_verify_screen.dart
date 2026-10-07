import 'package:flutter/material.dart';

import '../core/navigation/auth_reveal.dart';
import '../l10n/strings.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';
import 'payment_success_screen.dart';

class PaymentVerifyScreen extends StatefulWidget {
  const PaymentVerifyScreen({
    super.key,
    required this.amount,
    required this.passengerName,
    this.serialNumber,
    this.nfcUid,
  });

  final int amount;
  final String passengerName;
  final String? serialNumber;
  final String? nfcUid;

  @override
  State<PaymentVerifyScreen> createState() => _PaymentVerifyScreenState();
}

class _PaymentVerifyScreenState extends State<PaymentVerifyScreen> {
  bool busy = false;
  String? fareKey;

  Future<void> confirm() async {
    final app = AppScope.of(context);
    final token = app.authToken ?? '';
    fareKey ??= newIdempotencyKey();
    setState(() => busy = true);
    try {
      final result = await ApiService.tapPay(
        token: token,
        amount: widget.amount,
        idempotencyKey: fareKey!,
        serialNumber: widget.serialNumber,
        nfcUid: widget.nfcUid,
      );
      fareKey = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      final reference = (result['reference'] ?? '').toString();
      await Navigator.pushReplacement(
        context,
        SoftFadeRoute(
          builder: (_) => PaymentSuccessScreen(
            amount: widget.amount,
            passengerName: widget.passengerName,
            reference: reference,
          ),
        ),
      );
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        app.refreshLedger(history: false);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S(AppScope.of(context).language);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.verifyTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: s.cancel,
            onPressed: busy ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 44,
              child: Text(
                widget.passengerName.substring(0, 1),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.passengerName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              s.passenger,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(s.nauli, style: const TextStyle(fontSize: 14)),
                  Text(
                    s.tzs(widget.amount),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              s.isSw
                  ? 'Bonyeza tiki kuthibitisha au X kughairi'
                  : 'Tap the tick to confirm or X to cancel',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 72,
                    child: OutlinedButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Icon(Icons.close, size: 40),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 72,
                    child: ElevatedButton(
                      onPressed: busy ? null : confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: busy
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 40),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      s.cancel,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      s.confirm,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

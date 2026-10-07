import 'package:flutter/material.dart';

import '../../../auth/money_amount.dart';
import '../../../l10n/strings.dart';
import '../../../nfc/nfc_uid.dart';
import '../../../services/api_service.dart';
import '../../../state/app_state.dart';

class TopUpCardPage extends StatefulWidget {
  const TopUpCardPage({super.key});

  @override
  State<TopUpCardPage> createState() => _TopUpCardPageState();
}

class _TopUpCardPageState extends State<TopUpCardPage> {
  final amount = TextEditingController();

  /// 0 = scan + owner details, 1 = enter amount
  int step = 0;
  bool busy = false;
  bool reading = false;

  String? nfcUid;
  String cardNumber = '';
  String holderName = '';
  String phone = '';
  String amountError = '';
  String? topUpKey;

  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> _scanCard() async {
    final s = S(AppScope.of(context).language);
    setState(() => reading = true);
    try {
      final uid = await readContactlessUid(
        timeout: const Duration(seconds: 12),
      );
      if (!mounted) return;
      if (uid == null || uid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.nfcHint)),
        );
        return;
      }

      final token = AppScope.of(context).authToken ?? '';
      final preview = await ApiService.previewTopUpScan(
        token: token,
        nfcUid: uid,
      );
      if (!mounted) return;

      final passenger = preview['passenger'] as Map<String, dynamic>? ?? {};
      final name = (passenger['name'] ??
              '${passenger['firstName'] ?? ''} ${passenger['lastName'] ?? ''}')
          .toString()
          .trim();

      setState(() {
        nfcUid = (preview['nfcUid'] ?? uid).toString();
        cardNumber = (preview['cardNumber'] ?? '').toString();
        holderName = name;
        phone = (passenger['phone'] ?? '').toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        nfcUid = null;
        cardNumber = '';
        holderName = '';
        phone = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => reading = false);
    }
  }

  void _goAmountStep() {
    final s = S(AppScope.of(context).language);
    if (nfcUid == null || nfcUid!.isEmpty || cardNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.scanCardFirst)),
      );
      return;
    }
    setState(() => step = 1);
  }

  Future<void> _confirmTopUp() async {
    final s = S(AppScope.of(context).language);
    final value = MoneyAmount.parse(amount.text);
    setState(() {
      amountError = value <= 0 ? s.amountRequired : '';
    });
    if (amountError.isNotEmpty) return;

    final token = AppScope.of(context).authToken ?? '';
    topUpKey ??= newIdempotencyKey();
    setState(() => busy = true);
    try {
      final result = await ApiService.topUpWallet(
        token: token,
        amount: value,
        nfcUid: nfcUid,
        serialNumber: cardNumber,
        idempotencyKey: topUpKey,
      );
      topUpKey = null;
      if (!mounted) return;

      final credited = (result['credited'] as num?)?.toInt() ?? value;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.topUpOk),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(holderName.isEmpty ? cardNumber : holderName),
              const SizedBox(height: 8),
              Text('${s.cardNumber}: $cardNumber'),
              Text('${s.amountAdded}: ${s.tzs(credited)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.done),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
        title: Text(s.topUpCard),
        leading: step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: busy ? null : () => setState(() => step = 0),
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final offset = Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offset, child: child),
          );
        },
        child: ListView(
          key: ValueKey(step),
          padding: const EdgeInsets.all(20),
          children: [
            _StepDots(step: step, total: 2),
            const SizedBox(height: 20),
            if (step == 0) ..._scanStep(s) else ..._amountStep(s),
          ],
        ),
      ),
    );
  }

  List<Widget> _scanStep(S s) {
    final scanned = nfcUid != null && nfcUid!.isNotEmpty;
    return [
      Text(
        s.scanCardStep,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      const SizedBox(height: 8),
      Text(
        s.topUpScanHint,
        style: TextStyle(color: Colors.grey.shade700),
      ),
      const SizedBox(height: 16),
      SizedBox(
        height: 54,
        child: OutlinedButton.icon(
          onPressed: reading ? null : _scanCard,
          icon: reading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.contactless),
          label: Text(reading ? s.scanning : s.scanCard),
        ),
      ),
      if (scanned) ...[
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.passenger,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                holderName.isEmpty ? '—' : holderName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(phone, style: TextStyle(color: Colors.grey.shade700)),
              ],
              const SizedBox(height: 14),
              _DetailRow(label: s.cardNumber, value: cardNumber),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _goAmountStep,
            child: Text(
              s.continueBtn,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _amountStep(S s) {
    return [
      Text(
        s.enterTopUpAmount,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      const SizedBox(height: 8),
      Text(
        holderName.isEmpty ? cardNumber : holderName,
        style: TextStyle(color: Colors.grey.shade700),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: amount,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: const [MoneyFormatter()],
        onChanged: (_) {
          if (amountError.isNotEmpty) setState(() => amountError = '');
        },
        decoration: InputDecoration(
          labelText: '${s.amount} *',
          hintText: s.amountRequired,
          prefixIcon: const Icon(Icons.payments_outlined),
          errorText: amountError.isEmpty ? null : amountError,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: busy ? null : _confirmTopUp,
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  s.done,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    ];
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == step;
        final done = i < step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: active ? 28 : 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: done || active
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

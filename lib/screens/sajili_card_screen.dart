import 'package:flutter/material.dart';

import '../auth/money_amount.dart';
import '../auth/tz_phone.dart';
import '../l10n/strings.dart';
import '../nfc/nfc_uid.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';

class SajiliCardScreen extends StatefulWidget {
  const SajiliCardScreen({super.key});

  @override
  State<SajiliCardScreen> createState() => _SajiliCardScreenState();
}

class _SajiliCardScreenState extends State<SajiliCardScreen> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  final card = TextEditingController();
  final uid = TextEditingController();
  final load = TextEditingController();

  /// 0 = passenger details, 1 = NFC scan, 2 = initial top-up + sajili
  int step = 0;
  bool busy = false;
  bool reading = false;

  @override
  void initState() {
    super.initState();
    phone.text = TzPhone.format('');
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    card.dispose();
    uid.dispose();
    load.dispose();
    super.dispose();
  }

  Future<void> _scanCard() async {
    final s = S(AppScope.of(context).language);
    setState(() => reading = true);
    try {
      final value = await readContactlessUid(
        timeout: const Duration(seconds: 12),
      );
      if (!mounted) return;
      if (value == null || value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.nfcHint)),
        );
        return;
      }

      final token = AppScope.of(context).authToken ?? '';
      final preview = await ApiService.scanCard(
        token: token,
        nfcUid: value,
      );
      if (!mounted) return;

      if (preview['alreadyIssued'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              preview['message']?.toString() ?? s.cardAlreadyRegistered,
            ),
          ),
        );
        return;
      }

      setState(() {
        uid.text = (preview['nfcUid'] ?? value).toString();
        card.text = (preview['cardNumber'] ?? '').toString();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => reading = false);
    }
  }

  void _goPassengerNext() {
    final s = S(AppScope.of(context).language);
    if (firstName.text.trim().isEmpty ||
        lastName.text.trim().isEmpty ||
        !TzPhone.isValid(phone.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.fillAll)),
      );
      return;
    }
    setState(() => step = 1);
  }

  void _goScanNext() {
    final s = S(AppScope.of(context).language);
    if (uid.text.trim().isEmpty || card.text.trim().length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.scanCardFirst)),
      );
      return;
    }
    setState(() => step = 2);
  }

  Future<void> _register() async {
    final s = S(AppScope.of(context).language);
    final amount = MoneyAmount.parse(load.text);
    if (amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.amountRequired)),
      );
      return;
    }

    final token = AppScope.of(context).authToken ?? '';
    setState(() => busy = true);
    try {
      final result = await ApiService.issueCard(
        token: token,
        firstName: firstName.text,
        lastName: lastName.text,
        phone: TzPhone.toApi(phone.text),
        serialNumber: card.text.trim(),
        nfcUid: uid.text.trim(),
        initialLoad: amount,
      );
      if (!mounted) return;

      final cardData = result['card'] as Map<String, dynamic>? ?? {};
      final balance = (cardData['balance'] as num?)?.toInt() ?? amount;
      final smsNote = result['smsQueued'] == true ? '\n${s.smsSentHint}' : '';

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.cardRegistered),
          content: Text(
            '${'${firstName.text.trim()} ${lastName.text.trim()}'.toUpperCase()}\n'
            '${card.text.trim()}\n'
            '${s.newBalance}: ${s.tzs(balance)}$smsNote',
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
        title: Text(s.sajiliCard),
        leading: step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: busy
                    ? null
                    : () => setState(() => step = step - 1),
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
            _StepDots(step: step),
            const SizedBox(height: 20),
            if (step == 0) ..._passengerStep(s),
            if (step == 1) ..._scanStep(s),
            if (step == 2) ..._topUpStep(s),
          ],
        ),
      ),
    );
  }

  List<Widget> _passengerStep(S s) {
    return [
      Text(
        s.passengerDetailsStep,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: firstName,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: '${s.firstName} *',
          prefixIcon: const Icon(Icons.person_outline),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: lastName,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: '${s.lastName} *',
          prefixIcon: const Icon(Icons.person_outline),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: phone,
        keyboardType: TextInputType.phone,
        inputFormatters: const [TzPhoneFormatter()],
        decoration: InputDecoration(
          labelText: '${s.phone} *',
          prefixIcon: const Icon(Icons.phone_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: _goPassengerNext,
          child: Text(
            s.continueBtn,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    ];
  }

  List<Widget> _scanStep(S s) {
    return [
      Text(
        s.scanCardStep,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      const SizedBox(height: 8),
      Text(
        s.scanCardStepHint,
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
      const SizedBox(height: 16),
      TextField(
        controller: uid,
        readOnly: true,
        decoration: InputDecoration(
          labelText: s.nfcUid,
          prefixIcon: const Icon(Icons.nfc),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: card,
        readOnly: true,
        decoration: InputDecoration(
          labelText: s.cardNumber,
          hintText: '12 ${s.digits}',
          prefixIcon: const Icon(Icons.credit_card),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: _goScanNext,
          child: Text(
            s.continueBtn,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    ];
  }

  List<Widget> _topUpStep(S s) {
    return [
      Text(
        s.initialTopUpStep,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      const SizedBox(height: 8),
      Text(
        '${'${firstName.text.trim()} ${lastName.text.trim()}'.toUpperCase()} · ${card.text.trim()}',
        style: TextStyle(color: Colors.grey.shade700),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: load,
        keyboardType: TextInputType.number,
        inputFormatters: const [MoneyFormatter()],
        decoration: InputDecoration(
          labelText: '${s.firstLoad} *',
          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: busy ? null : _register,
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  s.sajiliCard,
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

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == step;
        final done = i < step;
        return Container(
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

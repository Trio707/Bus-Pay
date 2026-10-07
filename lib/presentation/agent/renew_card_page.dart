import 'package:flutter/material.dart';

import '../../../auth/money_amount.dart';
import '../../../core/di/injection.dart';
import '../../../l10n/strings.dart';
import '../../../nfc/nfc_uid.dart';
import '../../../services/api_service.dart';
import '../../../state/app_state.dart';

class RenewCardPage extends StatefulWidget {
  const RenewCardPage({super.key});

  @override
  State<RenewCardPage> createState() => _RenewCardPageState();
}

class _RenewCardPageState extends State<RenewCardPage> {
  final card = TextEditingController();
  final load = TextEditingController();
  bool busy = false;
  String? renewKey;
  bool reading = false;
  String? passengerName;
  String? phone;
  int? balance;
  String? newUid;

  @override
  void dispose() {
    card.dispose();
    load.dispose();
    super.dispose();
  }

  Future<void> lookup() async {
    final s = S(AppScope.of(context).language);
    if (card.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.cardRequired)),
      );
      return;
    }
    final token = AppScope.of(context).authToken ?? '';
    setState(() => busy = true);
    try {
      final result = await ApiService.lookupCard(
        token: token,
        serialNumber: card.text.trim(),
      );
      if (!mounted) return;
      final cardData = result['card'] as Map<String, dynamic>? ?? {};
      final customer = result['customer'] as Map<String, dynamic>? ?? {};
      final number = (cardData['cardNumber'] ?? cardData['serialNumber'] ?? '')
          .toString();
      setState(() {
        if (number.isNotEmpty) card.text = number;
        passengerName =
            '${customer['firstName'] ?? ''} ${customer['lastName'] ?? ''}'
                .trim();
        phone = customer['phone']?.toString();
        balance = (cardData['balance'] as num?)?.toInt();
        newUid = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> scanNewCard() async {
    final s = S(AppScope.of(context).language);
    setState(() => reading = true);
    try {
      final value = await readContactlessUid(
        timeout: const Duration(seconds: 20),
      );
      if (!mounted) return;
      if (value == null || value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.nfcHint)),
        );
        return;
      }
      setState(() => newUid = value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => reading = false);
    }
  }

  Future<void> submit() async {
    final s = S(AppScope.of(context).language);
    final number = card.text.trim();
    final uid = newUid?.trim() ?? '';
    if (number.isEmpty || passengerName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.cardRequired)),
      );
      return;
    }
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.scanNewCardHint)),
      );
      return;
    }
    final token = AppScope.of(context).authToken ?? '';
    renewKey ??= newIdempotencyKey();
    setState(() => busy = true);
    try {
      final result = await Injection.renewCard(
        token: token,
        serialNumber: number,
        nfcUid: uid,
        amount: MoneyAmount.parse(load.text),
        idempotencyKey: renewKey,
      );
      renewKey = null;
      if (!mounted) return;
      final cardData = result['card'] as Map<String, dynamic>? ?? {};
      final kept =
          (cardData['cardNumber'] ?? cardData['serialNumber'] ?? number)
              .toString();
      final nextBalance = (cardData['balance'] as num?)?.toInt() ?? balance;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.cardRenewed),
          content: Text(
            '${s.cardNumber}: $kept\n'
            '${s.cardNumberKept}'
            '${nextBalance == null ? '' : '\n${s.newBalance}: ${s.tzs(nextBalance)}'}',
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
    final identified = passengerName != null;
    return Scaffold(
      appBar: AppBar(title: Text(s.renewCard)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: card,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: s.lostCardNumber,
              prefixIcon: const Icon(Icons.credit_card),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: busy ? null : lookup,
              child: Text(s.continueBtn),
            ),
          ),
          if (identified) ...[
            const SizedBox(height: 22),
            Text(
              passengerName!,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (phone != null && phone!.isNotEmpty)
              Text(phone!, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            Text(
              '${s.cardNumber}: ${card.text.trim()}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(s.cardNumberKept),
            if (balance != null) ...[
              const SizedBox(height: 6),
              Text('${s.currentBalance}: ${s.tzs(balance!)}'),
            ],
            const SizedBox(height: 18),
            Text(s.scanNewCardHint),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: busy || reading ? null : scanNewCard,
                icon: reading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.nfc),
                label: Text(s.scanNewCard),
              ),
            ),
            if (newUid != null) ...[
              const SizedBox(height: 10),
              Text('NFC UID: $newUid'),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: load,
              keyboardType: TextInputType.number,
              inputFormatters: const [MoneyFormatter()],
              decoration: InputDecoration(
                labelText: s.firstLoad,
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: busy ? null : submit,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        s.renewCard,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/money_amount.dart';
import '../l10n/strings.dart';
import '../services/api_service.dart';
import '../state/app_state.dart';

class ToaPesaScreen extends StatefulWidget {
  const ToaPesaScreen({super.key});

  @override
  State<ToaPesaScreen> createState() => _ToaPesaScreenState();
}

class _ToaPesaScreenState extends State<ToaPesaScreen> {
  final tillController = TextEditingController();
  final amountController = TextEditingController();
  final providerController = TextEditingController();
  final destinationController = TextEditingController();
  final accountNameController = TextEditingController();

  /// 0 = choose method, 1 = wakala TILL, 2 = cash amount, 3 = electronic payout
  int step = 0;
  String method = '';
  bool busy = false;
  bool quoting = false;
  String? tillNormalized;
  String agentName = '';
  String amountError = '';
  String? payoutKey;
  String? cashOutKey;
  int? quoteFee;
  int? quoteTotal;
  int? quotedFor;
  int _quoteGeneration = 0;
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context).refreshLedger(history: false);
    });
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    tillController.dispose();
    amountController.dispose();
    providerController.dispose();
    destinationController.dispose();
    accountNameController.dispose();
    super.dispose();
  }

  Future<void> _lookupTill() async {
    final s = S(AppScope.of(context).language);
    final till = tillController.text.trim();
    if (till.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.fillAll)),
      );
      return;
    }

    final token = AppScope.of(context).authToken ?? '';
    setState(() => busy = true);
    try {
      final data = await ApiService.lookupWakalaTill(
        token: token,
        tillNumber: till,
      );
      if (!mounted) return;
      final agent = data['agent'] as Map<String, dynamic>? ?? {};
      setState(() {
        tillNormalized = (data['tillNumber'] ?? till).toString();
        agentName = (agent['name'] ?? '').toString().trim();
        step = 1;
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

  void _clearQuote() {
    _quoteTimer?.cancel();
    _quoteGeneration++;
    quoteFee = null;
    quoteTotal = null;
    quotedFor = null;
    quoting = false;
  }

  void _onAmountChanged() {
    final generation = ++_quoteGeneration;
    _quoteTimer?.cancel();
    final amount = MoneyAmount.parse(amountController.text);
    setState(() {
      quoteFee = null;
      quoteTotal = null;
      quotedFor = null;
      amountError = '';
    });
    if (amount <= 0) return;
    _quoteTimer = Timer(const Duration(milliseconds: 350), () {
      _loadQuote(amount, generation);
    });
  }

  Future<void> _loadQuote(int amount, int generation) async {
    if (!mounted) return;
    final app = AppScope.of(context);
    final s = S(app.language);
    setState(() => quoting = true);
    try {
      final data = await ApiService.quoteConductorPayout(
        token: app.authToken ?? '',
        amount: amount,
      );
      if (!mounted || generation != _quoteGeneration) return;
      final fee = (data['fee'] as num?)?.toInt();
      final total = (data['totalDebit'] as num?)?.toInt();
      final net = (data['netAmount'] as num?)?.toInt();
      if (fee == null || total == null || net != amount) {
        setState(() => amountError = s.amountRequired);
        return;
      }
      setState(() {
        quoteFee = fee;
        quoteTotal = total;
        quotedFor = amount;
        amountError = total > app.walletBalance ? s.payoutInsufficient : '';
      });
    } catch (e) {
      if (!mounted || generation != _quoteGeneration) return;
      setState(() {
        amountError = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted && generation == _quoteGeneration) {
        setState(() => quoting = false);
      }
    }
  }

  bool _quoteReady(int amount) {
    return !quoting &&
        amount > 0 &&
        quotedFor == amount &&
        quoteFee != null &&
        quoteTotal != null &&
        amountError.isEmpty;
  }

  Future<bool> _confirmBreakdown(S s, int amount, int fee, int total) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.amountYouReceive}: ${s.tzs(amount)}'),
            const SizedBox(height: 6),
            Text('${s.payoutFee}: ${s.tzs(fee)}'),
            const SizedBox(height: 6),
            Text(
              '${s.payoutTotalDebit}: ${s.tzs(total)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.back),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.confirmPayout),
          ),
        ],
      ),
    );
    return ok == true;
  }

  List<Widget> _quoteLines(S s) {
    if (quoteFee == null || quoteTotal == null || quotedFor == null) {
      if (!quoting) return const [];
      return const [
        SizedBox(height: 12),
        LinearProgressIndicator(),
      ];
    }
    return [
      const SizedBox(height: 12),
      Text('${s.amountYouReceive}: ${s.tzs(quotedFor!)}'),
      const SizedBox(height: 4),
      Text('${s.payoutFee}: ${s.tzs(quoteFee!)}'),
      const SizedBox(height: 4),
      Text(
        '${s.payoutTotalDebit}: ${s.tzs(quoteTotal!)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ];
  }

  Future<void> _withdraw() async {
    final app = AppScope.of(context);
    final s = S(app.language);
    final amount = MoneyAmount.parse(amountController.text);
    if (tillNormalized == null || !_quoteReady(amount)) return;
    final fee = quoteFee!;
    final total = quoteTotal!;
    if (!await _confirmBreakdown(s, amount, fee, total)) return;
    if (!mounted) return;

    final token = app.authToken ?? '';
    cashOutKey ??= newIdempotencyKey();
    setState(() => busy = true);
    try {
      final result = await ApiService.withdrawToWakala(
        token: token,
        tillNumber: tillNormalized!,
        amount: amount,
        idempotencyKey: cashOutKey,
      );
      cashOutKey = null;
      if (!mounted) return;

      await app.refreshLedger(history: false);
      if (!mounted) return;

      final reference = (result['reference'] ?? '').toString();
      final agent = result['agent'] as Map<String, dynamic>? ?? {};
      final name =
          (agent['name'] ?? agentName).toString().trim();
      final available = (result['available'] as num?)?.toInt() ??
          AppScope.of(context).walletBalance;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.withdrawOk),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name.isEmpty ? (tillNormalized ?? '') : name),
              Text('${s.wakalaTill}: ${tillNormalized ?? ''}'),
              const SizedBox(height: 8),
              Text('${s.amountYouReceive}: ${s.tzs(amount)}'),
              Text('${s.payoutFee}: ${s.tzs((result['fee'] as num?)?.toInt() ?? fee)}'),
              Text(
                '${s.payoutTotalDebit}: ${s.tzs((result['totalDebit'] as num?)?.toInt() ?? total)}',
              ),
              if (reference.isNotEmpty) Text('${s.reference}: $reference'),
              Text(
                '${s.newBalance}: ${s.tzs(available)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
      tillController.clear();
      amountController.clear();
      setState(() {
        step = 0;
        method = '';
        tillNormalized = null;
        agentName = '';
        amountError = '';
        _clearQuote();
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

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = S(app.language);

    return AnimatedSwitcher(
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
      child: RefreshIndicator(
        onRefresh: () => app.refreshLedger(history: false),
        child: ListView(
        key: ValueKey(step),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: Text(s.wallet),
              trailing: Text(
                s.tzs(app.walletBalance),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (step == 0)
            ..._methodStep(s)
          else if (step == 1)
            ..._tillStep(s)
          else if (step == 2)
            ..._amountStep(s, app)
          else
            ..._electronicStep(s, app),
        ],
        ),
      ),
    );
  }

  List<Widget> _methodStep(S s) {
    return [
      Text(
        s.toaPesaHint,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      _methodButton(s.cashAtWakala, Icons.storefront_outlined, () {
        setState(() {
          method = 'CASH';
          step = 1;
        });
      }),
      const SizedBox(height: 10),
      _methodButton(s.mobileMoney, Icons.phone_android, () {
        setState(() {
          method = 'MOBILE_MONEY';
          step = 3;
        });
      }),
      const SizedBox(height: 10),
      _methodButton(s.bankAccount, Icons.account_balance, () {
        setState(() {
          method = 'BANK';
          step = 3;
        });
      }),
    ];
  }

  Widget _methodButton(String label, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  List<Widget> _tillStep(S s) {
    return [
      Text(
        s.cashAtWakala,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text(
        s.toaPesaTillHint,
        style: TextStyle(color: Colors.grey.shade700),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: busy ? null : () => setState(() => step = 0), child: Text(s.back)),
      ),
      TextField(
        controller: tillController,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d-]'))],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => busy ? null : _lookupTill(),
        decoration: InputDecoration(
          labelText: '${s.wakalaTill} *',
          prefixIcon: const Icon(Icons.storefront_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: busy ? null : _lookupTill,
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  s.continueBtn,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    ];
  }

  List<Widget> _amountStep(S s, AppState app) {
    return [
      Text(
        s.enterWithdrawAmount,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              agentName.isEmpty ? (tillNormalized ?? '') : agentName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              '${s.wakalaTill}: ${tillNormalized ?? ''}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: amountController,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: const [MoneyFormatter()],
        onChanged: (_) => _onAmountChanged(),
        decoration: InputDecoration(
          labelText: '${s.amountYouReceive} *',
          prefixIcon: const Icon(Icons.payments_outlined),
          errorText: amountError.isEmpty ? null : amountError,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      ..._quoteLines(s),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                        step = 1;
                        amountController.clear();
                        amountError = '';
                        _clearQuote();
                      }),
              child: Text(s.back),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: busy || !_quoteReady(MoneyAmount.parse(amountController.text))
                    ? null
                    : _withdraw,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        s.withdraw,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _submitPayout() async {
    final app = AppScope.of(context);
    final s = S(app.language);
    final amount = MoneyAmount.parse(amountController.text);
    final provider = providerController.text.trim();
    final destination = destinationController.text.trim();
    if (amount <= 0) {
      setState(() => amountError = s.amountRequired);
    }
    if (amountError.isNotEmpty || !_quoteReady(amount) || provider.isEmpty || destination.isEmpty) {
      if (provider.isEmpty || destination.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.fillAll)));
      }
      return;
    }
    final fee = quoteFee!;
    final total = quoteTotal!;
    if (!await _confirmBreakdown(s, amount, fee, total)) return;
    if (!mounted) return;

    payoutKey ??= 'app${DateTime.now().microsecondsSinceEpoch}';
    setState(() => busy = true);
    try {
      final result = await ApiService.requestConductorPayout(
        token: app.authToken ?? '',
        method: method,
        provider: provider,
        amount: amount,
        idempotencyKey: payoutKey!,
        mobileNumber: method == 'MOBILE_MONEY' ? destination : null,
        accountNumber: method == 'BANK' ? destination : null,
        accountName: accountNameController.text.trim(),
      );
      if (!mounted) return;
      await app.refreshLedger(history: false);
      if (!mounted) return;
      final status = (result['status'] ?? '').toString();
      final reference = (result['reference'] ?? '').toString();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(status.isEmpty ? s.payoutPending : s.payoutStatus(status)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((result['message'] ?? s.payoutPending).toString()),
              const SizedBox(height: 8),
              Text('${s.amountYouReceive}: ${s.tzs((result['netAmount'] as num?)?.toInt() ?? amount)}'),
              Text('${s.payoutFee}: ${s.tzs((result['fee'] as num?)?.toInt() ?? fee)}'),
              Text(
                '${s.payoutTotalDebit}: ${s.tzs((result['totalDebit'] as num?)?.toInt() ?? total)}',
              ),
              if (reference.isNotEmpty) Text('${s.reference}: $reference'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.done)),
          ],
        ),
      );
      if (!mounted) return;
      amountController.clear();
      providerController.clear();
      destinationController.clear();
      accountNameController.clear();
      setState(() {
        step = 0;
        method = '';
        payoutKey = null;
        amountError = '';
        _clearQuote();
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

  List<Widget> _electronicStep(S s, AppState app) {
    final isBank = method == 'BANK';
    return [
      Text(
        isBank ? s.bankAccount : s.mobileMoney,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text(s.payoutProviderHint, style: TextStyle(color: Colors.grey.shade700)),
      const SizedBox(height: 16),
      TextField(
        controller: providerController,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: '${s.payoutProvider} *',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: destinationController,
        keyboardType: isBank ? TextInputType.text : TextInputType.phone,
        decoration: InputDecoration(
          labelText: isBank ? '${s.accountNumber} *' : '${s.phone} *',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      if (isBank) ...[
        const SizedBox(height: 12),
        TextField(
          controller: accountNameController,
          decoration: InputDecoration(
            labelText: s.accountName,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
      const SizedBox(height: 12),
      TextField(
        controller: amountController,
        keyboardType: TextInputType.number,
        inputFormatters: const [MoneyFormatter()],
        onChanged: (_) => _onAmountChanged(),
        decoration: InputDecoration(
          labelText: '${s.amountYouReceive} *',
          errorText: amountError.isEmpty ? null : amountError,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      ..._quoteLines(s),
      const SizedBox(height: 8),
      Text('${s.wallet}: ${s.tzs(app.walletBalance)}'),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                        step = 0;
                        method = '';
                        payoutKey = null;
                        amountError = '';
                        _clearQuote();
                      }),
              child: Text(s.back),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: busy || !_quoteReady(MoneyAmount.parse(amountController.text))
                    ? null
                    : _submitPayout,
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(s.confirm, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    ];
  }
}

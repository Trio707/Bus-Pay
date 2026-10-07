import 'package:flutter/material.dart';

import '../auth/money_amount.dart';
import '../core/navigation/app_page_route.dart';
import '../core/sound/key_click.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import '../widgets/wallet_balance.dart';
import 'nfc_scanner_screen.dart';

class MalipoScreen extends StatefulWidget {
  const MalipoScreen({super.key});

  @override
  State<MalipoScreen> createState() => _MalipoScreenState();
}

class _MalipoScreenState extends State<MalipoScreen> {
  String fare = '';

  @override
  void initState() {
    super.initState();
    KeyClick.warmUp();
  }

  void addNumber(String number) {
    if (fare.length >= 7) return;
    KeyClick.play();
    setState(() => fare += number);
  }

  void deleteNumber() {
    if (fare.isEmpty) return;
    KeyClick.play();
    setState(() => fare = fare.substring(0, fare.length - 1));
  }

  void clearFare() {
    if (fare.isEmpty) return;
    KeyClick.play();
    setState(() => fare = '');
  }

  Future<void> lipia() async {
    final s = S(AppScope.of(context).language);
    if (fare.isEmpty || int.tryParse(fare) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.enterFare)),
      );
      return;
    }

    await Navigator.push(
      context,
      AppPageRoute(
        builder: (_) => NfcScannerScreen(amount: int.parse(fare)),
      ),
    );

    if (mounted) clearFare();
  }

  Widget numberButton(String number) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: SizedBox(
          height: 62,
          child: ElevatedButton(
            onPressed: () => addNumber(number),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              number,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = S(app.language);

    return SafeArea(
      child: RefreshIndicator(
      onRefresh: () => app.refreshLedger(history: false),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.wallet,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const WalletBalanceText(
                  showToggle: true,
                  toggleColor: Colors.white,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.isSw
                      ? 'Salio linaongezeka baada ya kila malipo'
                      : 'Balance increases after every payment',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(18),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              children: [
                Text(
                  s.nauli,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fare.isEmpty ? 'TZS 0' : 'TZS ${MoneyAmount.format(fare)}',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
              ],
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Row(children: [numberButton('1'), numberButton('2'), numberButton('3')]),
                  Row(children: [numberButton('4'), numberButton('5'), numberButton('6')]),
                  Row(children: [numberButton('7'), numberButton('8'), numberButton('9')]),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: SizedBox(
                            height: 62,
                            child: ElevatedButton(
                              onPressed: clearFare,
                              child: const Text(
                                'C',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      numberButton('0'),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: SizedBox(
                            height: 62,
                            child: ElevatedButton(
                              onPressed: deleteNumber,
                              child: const Icon(Icons.backspace_outlined),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: lipia,
                icon: const Icon(Icons.contactless),
                label: Text(
                  s.lipia,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

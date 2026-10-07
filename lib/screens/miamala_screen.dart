import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';

class MiamalaScreen extends StatefulWidget {
  const MiamalaScreen({super.key});

  @override
  State<MiamalaScreen> createState() => _MiamalaScreenState();
}

class _MiamalaScreenState extends State<MiamalaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = AppScope.of(context);
      if (!app.dataSaver) _reload();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => loading = true);
    await AppScope.of(context).refreshLedger();
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = S(app.language);
    final payments =
        app.transactions.where((tx) => tx.type == TransactionType.nauli).toList();
    final withdrawals = app.transactions
        .where((tx) => tx.type == TransactionType.toaPesa)
        .toList();

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: s.paymentsTab),
              Tab(text: s.withdrawalsTab),
            ],
          ),
        ),
        Expanded(
          child: loading && app.transactions.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _TxList(
                      items: payments,
                      emptyLabel: s.noTx,
                      onRefresh: _reload,
                      language: app.language,
                      inbound: true,
                      hasMore: app.ledgerHasMore,
                      onLoadMore: app.loadMoreLedger,
                    ),
                    _TxList(
                      items: withdrawals,
                      emptyLabel: s.noWithdrawals,
                      onRefresh: _reload,
                      language: app.language,
                      inbound: false,
                      hasMore: app.ledgerHasMore,
                      onLoadMore: app.loadMoreLedger,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TxList extends StatelessWidget {
  const _TxList({
    required this.items,
    required this.emptyLabel,
    required this.onRefresh,
    required this.language,
    required this.inbound,
    required this.hasMore,
    required this.onLoadMore,
  });

  final List<Transaction> items;
  final String emptyLabel;
  final Future<void> Function() onRefresh;
  final AppLanguage language;
  final bool inbound;
  final bool hasMore;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final s = S(language);

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.45,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      inbound ? Icons.receipt_long : Icons.storefront_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(emptyLabel, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          if (i >= items.length) {
            return TextButton(
              onPressed: onLoadMore,
              child: Text(s.loadMore),
            );
          }
          final tx = items[i];
          final isIn = inbound && tx.type == TransactionType.nauli;
          final subtitle = switch (tx.type) {
            TransactionType.nauli => tx.reference.isEmpty
                ? s.paid
                : '${s.paid} • ${tx.reference}',
            TransactionType.toaPesa => tx.totalDebit == null
                ? (tx.reference.isEmpty
                    ? '${s.withdrawn} • ${tx.detail}'
                    : '${s.withdrawn} • ${tx.detail} • ${tx.reference}')
                : '${s.amountYouReceive} ${s.tzs(tx.amount)}\n'
                    '${s.payoutFee} ${s.tzs(tx.fee ?? 0)}\n'
                    '${s.payoutTotalDebit} ${s.tzs(tx.totalDebit!)}\n'
                    '${s.payoutStatus(tx.detail)}'
                    '${tx.reference.isEmpty ? '' : ' • ${tx.reference}'}',
            TransactionType.tumaPesa => '${s.sent} • ${tx.detail}',
          };
          final time =
              '${tx.time.hour.toString().padLeft(2, '0')}:${tx.time.minute.toString().padLeft(2, '0')}';

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isIn
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                child: Icon(
                  isIn ? Icons.person : Icons.storefront_outlined,
                  color: isIn ? Colors.green : Colors.orange,
                ),
              ),
              title: Text(
                tx.passengerName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                tx.totalDebit == null ? '$subtitle • $time' : '$subtitle\n$time',
                maxLines: 6,
              ),
              isThreeLine: tx.totalDebit != null,
              trailing: Text(
                '${isIn ? '+' : '-'}${s.tzs(tx.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIn ? Colors.green : Colors.orange.shade800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

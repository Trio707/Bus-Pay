import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';

class FloatHistoryPage extends StatefulWidget {
  const FloatHistoryPage({super.key});

  @override
  State<FloatHistoryPage> createState() => _FloatHistoryPageState();
}

class _FloatHistoryPageState extends State<FloatHistoryPage> {
  final List<Map<String, dynamic>> _rows = [];
  int _page = 0;
  bool _loading = true;
  bool _more = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _reload() => _load();

  Future<void> _load({bool more = false}) async {
    final app = AppScope.of(context);
    final token = app.authToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _rows.clear();
      });
      return;
    }
    final page = more ? _page + 1 : 1;
    setState(() => _loading = !more);
    try {
      final data = await ApiService.getAgentFloatTransactions(
        token: token,
        page: page,
        limit: app.historyPageSize,
      );
      final raw = data['transactions'];
      final incoming = raw is List
          ? raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
          : <Map<String, dynamic>>[];
      final total = (data['total'] as num?)?.toInt() ?? incoming.length;
      if (!mounted) return;
      setState(() {
        _page = page;
        if (!more) _rows.clear();
        _rows.addAll(incoming);
        _more = _rows.length < total;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : '$error';
      });
    }
  }

  String _label(S s, String type) {
    return switch (type) {
      'FLOAT_FUNDING' => s.floatFunding,
      'PASSENGER_TOPUP' => s.topUpCard,
      'CONDUCTOR_WITHDRAWAL' => s.conductorWithdrawal,
      'ADJUSTMENT' => s.floatAdjustment,
      _ => type,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = S(AppScope.of(context).language);
    return Scaffold(
      appBar: AppBar(title: Text(s.floatHistory)),
      body: Builder(
        builder: (context) {
          if (_loading && _rows.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null && _rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!),
              ),
            );
          }
          final rows = _rows;
          if (rows.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.5,
                    child: Center(child: Text(s.noFloatHistory)),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: rows.length + (_more ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index >= rows.length) {
                return TextButton(
                  onPressed: _loading ? null : () => _load(more: true),
                  child: Text(s.loadMore),
                );
              }
              final row = rows[index];
              final type = (row['type'] ?? '').toString();
              final amount = (row['amount'] as num?)?.toInt() ?? 0;
              final after = (row['balanceAfter'] as num?)?.toInt() ?? 0;
              final reference = (row['reference'] ?? '').toString();
              final created = DateTime.tryParse((row['createdAt'] ?? '').toString());
              final when = created == null
                  ? ''
                  : created.toLocal().toString().substring(0, 16);
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                title: Text(_label(s, type)),
                subtitle: Text(
                  [
                    s.tzs(amount),
                    '${s.balanceAfter}: ${s.tzs(after)}',
                    if (when.isNotEmpty) when,
                    if (reference.isNotEmpty) '${s.reference}: $reference',
                  ].join('\n'),
                ),
                isThreeLine: true,
              );
            },
            ),
          );
        },
      ),
    );
  }
}

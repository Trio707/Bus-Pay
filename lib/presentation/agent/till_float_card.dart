import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/navigation/app_page_route.dart';
import '../../l10n/strings.dart';
import '../../services/api_service.dart';
import '../../state/app_state.dart';
import 'float_history_page.dart';

class TillFloatCard extends StatefulWidget {
  const TillFloatCard({super.key});

  @override
  State<TillFloatCard> createState() => TillFloatCardState();
}

class TillFloatCardState extends State<TillFloatCard> {
  Future<void> reload() => _load();
  final _pages = PageController();
  int _page = 0;
  bool _revealed = false;
  int? _balance;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = AppScope.of(context).authToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Missing session';
      });
      return;
    }
    try {
      final data = await ApiService.getAgentFloat(token: token);
      if (!mounted) return;
      setState(() {
        _balance = (data['balance'] as num?)?.toInt() ?? 0;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _balance = null;
        _error = error is ApiException ? error.message : '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = S(app.language);
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 156,
          child: PageView(
            controller: _pages,
            onPageChanged: (value) => setState(() => _page = value),
            children: [
              _panel(
                primary: primary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.displayName,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      app.agentTill,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.wakalaDesk,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      s.slideForFloat,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _panel(
                primary: primary,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _revealed = !_revealed),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.availableFloat,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: _revealed ? 0 : 14,
                          sigmaY: _revealed ? 0 : 14,
                        ),
                        child: Text(
                          _loading
                              ? '...'
                              : _balance == null
                                  ? '—'
                                  : s.tzs(_balance!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _error ?? (_revealed ? s.tapToHide : s.tapToReveal),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _dot(active: _page == 0),
            const SizedBox(width: 6),
            _dot(active: _page == 1),
            const Spacer(),
            TextButton(
              onPressed: () => pushSmooth(context, const FloatHistoryPage()),
              child: Text(s.floatHistory),
            ),
          ],
        ),
      ],
    );
  }

  Widget _panel({required Color primary, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }

  Widget _dot({required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 16 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

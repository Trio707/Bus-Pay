import 'package:flutter/material.dart';

import '../../../core/navigation/app_page_route.dart';
import '../../../l10n/strings.dart';
import '../../../screens/login_screen.dart';
import '../../../screens/msaada_screen.dart';
import '../../../screens/profile_screen.dart';
import '../../../screens/sajili_card_screen.dart';
import '../../../state/app_state.dart';
import '../../../widgets/app_logo.dart';
import 'agent_settings_page.dart';
import 'renew_card_page.dart';
import 'top_up_card_page.dart';
import 'till_float_card.dart';
import 'widgets/floating_action_card.dart';

class AgentHomePage extends StatefulWidget {
  const AgentHomePage({super.key});

  @override
  State<AgentHomePage> createState() => _AgentHomePageState();
}

class _AgentHomePageState extends State<AgentHomePage> {
  final _floatKey = GlobalKey<TillFloatCardState>();

  Future<void> _refresh() async {
    await _floatKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = S(app.language);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 32, radius: 8),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                s.appName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.logout,
            onPressed: () {
              app.logout();
              Navigator.pushAndRemoveUntil(
                context,
                AppPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          TillFloatCard(key: _floatKey),
          const SizedBox(height: 22),
          Text(
            s.cardServices,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: primary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: [
              FloatingActionCard(
                icon: Icons.add_card_outlined,
                label: s.sajiliCard,
                subtitle: s.sajiliCardHint,
                onTap: () => pushSmooth(context, const SajiliCardScreen()),
              ),
              FloatingActionCard(
                icon: Icons.autorenew,
                label: s.renewCard,
                subtitle: s.renewCardHint,
                onTap: () => pushSmooth(context, const RenewCardPage()),
              ),
              FloatingActionCard(
                icon: Icons.account_balance_wallet_outlined,
                label: s.topUpCard,
                subtitle: s.topUpCardHint,
                onTap: () => pushSmooth(context, const TopUpCardPage()),
              ),
              FloatingActionCard(
                icon: Icons.person_outline,
                label: s.profile,
                subtitle: s.agent,
                onTap: () => pushSmooth(
                  context,
                  Scaffold(
                    appBar: AppBar(title: Text(s.profile)),
                    body: const ProfileScreen(),
                  ),
                ),
              ),
              FloatingActionCard(
                icon: Icons.settings_outlined,
                label: s.settings,
                subtitle: s.wakalaSettingsHint,
                onTap: () => pushSmooth(context, const AgentSettingsPage()),
              ),
              FloatingActionCard(
                icon: Icons.help_outline,
                label: s.msaada,
                subtitle: s.howToRegister,
                onTap: () => pushSmooth(context, const MsaadaScreen()),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/navigation/app_page_route.dart';
import '../../../l10n/strings.dart';
import '../../../screens/change_password_screen.dart';
import '../../../state/app_state.dart';

class AgentSettingsPage extends StatelessWidget {
  const AgentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = S(app.language);
    final primary = Theme.of(context).colorScheme.primary;
    final border = Theme.of(context).dividerColor;

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text(
            s.languageLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: primary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            child: SegmentedButton<AppLanguage>(
              segments: [
                ButtonSegment(
                  value: AppLanguage.sw,
                  label: Text(s.swahili),
                  icon: const Icon(Icons.translate, size: 18),
                ),
                ButtonSegment(
                  value: AppLanguage.en,
                  label: Text(s.english),
                  icon: const Icon(Icons.language, size: 18),
                ),
              ],
              selected: {app.language},
              onSelectionChanged: (value) => app.setLanguage(value.first),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            s.dataSaver,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: primary,
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.dataSaver),
            subtitle: Text(s.dataSaverHint),
            value: app.dataSaver,
            onChanged: app.setDataSaver,
          ),
          const SizedBox(height: 24),
          Text(
            s.security,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: primary,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => pushSmooth(context, const ChangePasswordScreen()),
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: ListTile(
                  leading: Icon(Icons.lock_outline, color: primary),
                  title: Text(
                    s.changePassword,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(s.changePasswordHint),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

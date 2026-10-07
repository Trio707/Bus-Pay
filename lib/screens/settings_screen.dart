import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = S(app.language);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(s.theme, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(value: ThemeMode.light, label: Text(s.light)),
            ButtonSegment(value: ThemeMode.dark, label: Text(s.dark)),
            ButtonSegment(value: ThemeMode.system, label: Text(s.system)),
          ],
          selected: {app.themeMode},
          onSelectionChanged: (value) => app.setTheme(value.first),
        ),
        const SizedBox(height: 24),
        Text(s.languageLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<AppLanguage>(
          segments: [
            ButtonSegment(value: AppLanguage.sw, label: Text(s.swahili)),
            ButtonSegment(value: AppLanguage.en, label: Text(s.english)),
          ],
          selected: {app.language},
          onSelectionChanged: (value) => app.setLanguage(value.first),
        ),
        const SizedBox(height: 24),
        Text(s.display, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<DisplaySize>(
          segments: [
            ButtonSegment(value: DisplaySize.compact, label: Text(s.compact)),
            ButtonSegment(value: DisplaySize.normal, label: Text(s.normal)),
            ButtonSegment(value: DisplaySize.large, label: Text(s.large)),
          ],
          selected: {app.displaySize},
          onSelectionChanged: (value) => app.setDisplaySize(value.first),
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.dataSaver),
          subtitle: Text(s.dataSaverHint),
          value: app.dataSaver,
          onChanged: app.setDataSaver,
        ),
      ],
    );
  }
}

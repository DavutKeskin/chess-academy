import 'package:flutter/material.dart';

import '../../core/settings_store.dart';
import '../../core/theme.dart';
import '../../core/widgets/choice_card.dart';
import '../../l10n/l10n.dart';
import '../home/home_screen.dart';

IconData ageIcon(AgeGroup a) => switch (a) {
      AgeGroup.child => Icons.child_care_rounded,
      AgeGroup.teen => Icons.school_rounded,
      AgeGroup.adult => Icons.person_rounded,
    };

/// İlk açılış: kim oynuyor, ne kadar biliyor? Cevaplar dersleri ve rakip seviyesini ayarlar.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  AgeGroup _age = AgeGroup.child;
  SkillLevel _level = SkillLevel.beginner;

  Future<void> _finish() async {
    await SettingsStore.instance.setProfile(age: _age, level: _level);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final settings = SettingsStore.instance;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Row(
              children: [
                Image.asset('assets/branding/icon.png', width: 72, height: 72),
                const Spacer(),
                // Dil seçimi: cihaz dili yanlışsa ilk ekranda değiştirilebilsin.
                ListenableBuilder(
                  listenable: settings,
                  builder: (context, _) => DropdownButton<String?>(
                    value: settings.language,
                    underline: const SizedBox.shrink(),
                    icon: Icon(Icons.language_rounded, color: AppColors.navy),
                    items: [
                      DropdownMenuItem<String?>(value: null, child: Text(t.languageSystem)),
                      for (final e in supportedLanguages.entries)
                        DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: settings.setLanguage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(t.welcomeTitle, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(t.welcomeSub, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.inkMuted)),
            const SizedBox(height: 28),
            Text(t.whoPlays, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final a in AgeGroup.values) ...[
                  Expanded(
                    child: ChoiceCard(
                      label: a.label(t),
                      hint: a.hint(t),
                      icon: ageIcon(a),
                      selected: _age == a,
                      onTap: () => setState(() => _age = a),
                    ),
                  ),
                  if (a != AgeGroup.values.last) const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Text(t.howMuchChess, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (final l in SkillLevel.values) ...[
              ChoiceCard(
                label: l.label(t),
                hint: l.hint(t),
                selected: _level == l,
                onTap: () => setState(() => _level = l),
                horizontal: true,
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _finish,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(t.letsStart),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../core/purchase_store.dart';
import '../../core/settings_store.dart';
import '../../core/theme.dart';
import '../../core/widgets/choice_card.dart';
import '../../l10n/l10n.dart';
import '../onboarding/onboarding_screen.dart' show ageIcon;
import '../paywall/paywall_screen.dart';

/// Uygulama GPL-3.0 (chessground, dartchess, stockfish); kaynak kodu bu adreste açık olmalı.
const sourceCodeUrl = 'https://github.com/DavutKeskin/chess-academy';

/// Ayarlar: görünüm (tahta, taşlar), geri bildirim, satın alma, profil, dil, hakkında.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _previewFen = 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';

  @override
  Widget build(BuildContext context) {
    final store = SettingsStore.instance;
    return Scaffold(
      appBar: AppBar(title: Text(context.t.settings)),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final t = context.t;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Center(
                child: LayoutBuilder(
                  builder: (context, c) => StaticChessboard(
                    size: (c.maxWidth * 0.78).clamp(200, 320),
                    orientation: Side.white,
                    fen: _previewFen,
                    settings: store.staticBoardSettings,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(t.boardAndPieces(store.board.label(t), store.pieces.label(t)),
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              const SizedBox(height: 20),
              _Section(
                title: t.boardSection,
                child: GridView.count(
                  crossAxisCount: 5,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.72,
                  children: [
                    for (final b in BoardTheme.values)
                      _BoardSwatch(theme: b, selected: b == store.board, onTap: () => store.setBoard(b)),
                  ],
                ),
              ),
              _Section(
                title: t.piecesSection,
                subtitle: t.piecesNote,
                child: GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.8,
                  children: [
                    for (final p in PieceStyle.values)
                      _PieceTile(style: p, selected: p == store.pieces, onTap: () => store.setPieces(p)),
                  ],
                ),
              ),
              _Section(
                title: t.themeSection,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.navyLight,
                    selectedForegroundColor: AppColors.navyDark,
                    foregroundColor: AppColors.ink,
                    side: BorderSide(color: AppColors.outline),
                  ),
                  segments: [
                    ButtonSegment(
                        value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_rounded), label: Text(t.themeSystem)),
                    ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_rounded), label: Text(t.themeLight)),
                    ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_rounded), label: Text(t.themeDark)),
                  ],
                  selected: {store.themeMode},
                  onSelectionChanged: (s) => store.setThemeMode(s.first),
                ),
              ),
              _Section(
                title: t.languageSection,
                child: Card(
                  child: Column(
                    children: [
                      RadioGroup<String?>(
                        groupValue: store.language,
                        onChanged: store.setLanguage,
                        child: Column(
                          children: [
                            RadioListTile<String?>(value: null, title: Text(t.languageSystem)),
                            for (final e in supportedLanguages.entries)
                              RadioListTile<String?>(value: e.key, title: Text(e.value)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _Section(
                title: t.feedbackSection,
                child: Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.volume_up_rounded),
                        title: Text(t.sounds),
                        subtitle: Text(t.soundsSub),
                        value: store.soundOn,
                        onChanged: store.setSound,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        secondary: const Icon(Icons.vibration_rounded),
                        title: Text(t.vibration),
                        subtitle: Text(t.vibrationSub),
                        value: store.hapticsOn,
                        onChanged: store.setHaptics,
                      ),
                    ],
                  ),
                ),
              ),
              _Section(
                title: t.allLessonsSection,
                child: ListenableBuilder(
                  listenable: PurchaseStore.instance,
                  builder: (context, _) {
                    final owned = PurchaseStore.instance.hasFullAccess;
                    return Card(
                      child: ListTile(
                        leading: Icon(owned ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                            color: owned ? AppColors.success : AppColors.goldInk),
                        title: Text(owned ? t.allLessonsOpen : t.unlockTacticLessons),
                        subtitle: Text(owned ? t.purchasedThanks : t.oneTimePrice(PurchaseStore.instance.priceText)),
                        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.navy),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _Section(
                title: t.profileSection,
                subtitle: store.lessonsUnlocked ? t.profileUnlocked(store.suggestedBotLevel) : t.profileSequential,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (final a in AgeGroup.values) ...[
                          Expanded(
                            child: ChoiceCard(
                              label: a.label(t),
                              hint: a.hint(t),
                              icon: ageIcon(a),
                              selected: store.age == a,
                              onTap: () => store.setProfile(age: a, level: store.level),
                            ),
                          ),
                          if (a != AgeGroup.values.last) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final l in SkillLevel.values) ...[
                      ChoiceCard(
                        label: l.label(t),
                        hint: l.hint(t),
                        horizontal: true,
                        selected: store.level == l,
                        onTap: () => store.setProfile(age: store.age, level: l),
                      ),
                      if (l != SkillLevel.values.last) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              _Section(
                title: t.aboutSection,
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.code_rounded),
                    title: Text(t.openSourceTitle),
                    subtitle: Text(t.openSourceSub),
                    trailing: Icon(Icons.chevron_right_rounded, color: AppColors.navy),
                    // Flutter, pub paketlerinin LICENSE dosyalarını bu sayfada kendisi listeler.
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: t.appName,
                      applicationLegalese: t.licenseLegalese(sourceCodeUrl),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _BoardSwatch extends StatelessWidget {
  const _BoardSwatch({required this.theme, required this.selected, required this.onTap});
  final BoardTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = theme.label(context.t);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? AppColors.navy : AppColors.outline, width: selected ? 2.5 : 1),
                  ),
                  child: LayoutBuilder(
                    builder: (context, c) => StaticChessboard(
                      size: c.maxWidth,
                      orientation: Side.white,
                      fen: '8/8/8/8/8/8/8/8',
                      settings: StaticChessboardSettings(
                        colorScheme: theme.colors,
                        pieceAssets: SettingsStore.instance.pieces.assets,
                        enableCoordinates: false,
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.2,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.navyDark : AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PieceTile extends StatelessWidget {
  const _PieceTile({required this.style, required this.selected, required this.onTap});
  final PieceStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = style.label(context.t);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.navyLight : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.navy : AppColors.outline, width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: Image(image: style.assets[PieceKind.whiteKing]!, fit: BoxFit.contain)),
                    Expanded(child: Image(image: style.assets[PieceKind.blackKnight]!, fit: BoxFit.contain)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w700, color: selected ? AppColors.navyDark : AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

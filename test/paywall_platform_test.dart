import 'package:chess_academy/core/settings_store.dart';
import 'package:chess_academy/features/paywall/paywall_screen.dart';
import 'package:chess_academy/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Store incelemesi başka bir platformdan (Google Play) söz eden uygulamayı reddeder.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsStore.instance.init();
  });

  Future<void> pumpPaywall(WidgetTester tester, String lang) async {
    // Uzun ekran: listenin tamamı kaydırmadan çizilsin ki her metin aranabilsin.
    tester.view.physicalSize = const Size(800, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(lang),
      home: const PaywallScreen(),
    ));
    await tester.pumpAndSettle();
  }

  for (final lang in ['tr', 'en', 'de', 'es']) {
    testWidgets('iOS satın alma ekranı Google Play demez ($lang)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final t = lookupAppLocalizations(Locale(lang));
        await pumpPaywall(tester, lang);
        expect(find.textContaining('Google'), findsNothing);
        expect(find.text(t.storeNoteIos), findsOneWidget);
        expect(find.text(t.benefitFamilyIos), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('Android satın alma ekranı Google Play metnini gösterir', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final t = lookupAppLocalizations(const Locale('tr'));
      await pumpPaywall(tester, 'tr');
      expect(find.text(t.storeNote), findsOneWidget);
      expect(find.textContaining('App Store'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

import 'package:chess_academy/core/settings_store.dart';
import 'package:chess_academy/features/settings/settings_screen.dart';
import 'package:chess_academy/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsStore.instance.init();
  });

  testWidgets('Hakkında: GPL bildirimi penceresi ve üçüncü taraf lisansları sayfası', (tester) async {
    final t = lookupAppLocalizations(const Locale('tr'));
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      home: const SettingsScreen(),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text(t.thirdPartyLicenses), 400, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('github.com/DavutKeskin/chess-academy'), findsOneWidget);

    await tester.tap(find.text(t.openSourceTitle));
    await tester.pumpAndSettle();
    expect(find.text(t.licenseLegalese(sourceCodeUrl)), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(t.closeBtn));
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.thirdPartyLicenses));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });
}

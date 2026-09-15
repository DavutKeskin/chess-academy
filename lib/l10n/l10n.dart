import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// `context.t.anahtar` kısayolu.
extension L10nContext on BuildContext {
  AppLocalizations get t => AppLocalizations.of(this);
}

/// Desteklenen diller ve görünen adları (kendi dillerinde).
const supportedLanguages = <String, String>{
  'tr': 'Türkçe',
  'en': 'English',
  'de': 'Deutsch',
  'es': 'Español',
};

import 'package:flutter/foundation.dart';

/// Mağaza ekran görüntüsü derlemesi (`--dart-define=SCREENSHOTS=true`): geliştirme derlemesine
/// özgü yardımcı arayüz (IP:port satırı, test kilidi) gizlenir; başka bir etkisi yoktur.
const bool kScreenshotMode = bool.fromEnvironment('SCREENSHOTS');

/// Yalnızca geliştiriciye görünen parçalar için: debug derlemesi ve ekran görüntüsü modu değil.
const bool kDevUi = kDebugMode && !kScreenshotMode;

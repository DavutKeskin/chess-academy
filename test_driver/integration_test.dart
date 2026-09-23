import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// `flutter drive` sürücüsü: uygulamadan gelen ekran görüntülerini `build/screenshots/AD.png` olarak yazar.
Future<void> main() => integrationDriver(
      onScreenshot: (name, bytes, [args]) async {
        final f = File('build/screenshots/$name.png');
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes);
        return true;
      },
    );

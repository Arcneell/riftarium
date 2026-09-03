import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/config.dart';

void main() {
  test('appVersion suit la version de pubspec.yaml', () {
    // `AppConfig.appVersion` part dans le User-Agent : une version figée à la
    // main finit toujours par mentir. Ce test le rappelle au moment du bump.
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    final version = line.split(':')[1].trim().split('+').first;

    expect(AppConfig.appVersion, version);
    expect(AppConfig.userAgent, 'Riftarium-Mobile/$version');
  });

  test('URL par défaut : production', () {
    expect(AppConfig.apiBaseUrl, 'https://riftarium.re/api');
    expect(AppConfig.webBaseUrl, 'https://riftarium.re');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/widgets/card_grid_metrics.dart';
import 'package:riftarium_mobile/app/widgets/card_image.dart';

void main() {
  group('cardGridMetrics', () {
    test('trois colonnes sur un téléphone tenu droit', () {
      final grid = cardGridMetrics(width: 390, gap: 10);

      expect(grid.columns, 3);
      // 390 - 36 de marges - 2 gouttières de 10, divisé par 3.
      expect(grid.tileWidth, closeTo((390 - 36 - 20) / 3, 0.001));
      expect(
        grid.imageHeight,
        closeTo(grid.tileWidth / CardImage.portraitRatio, 0.001),
      );
    });

    test('deux colonnes sur un très petit écran, quatre en paysage', () {
      expect(cardGridMetrics(width: 320, gap: 10).columns, 2);
      expect(cardGridMetrics(width: 640, gap: 10).columns, 4);
      expect(cardGridMetrics(width: 900, gap: 12).columns, 4);
    });

    test('largeur mesurée à zéro : vignette encore positive', () {
      final grid = cardGridMetrics(width: 0, gap: 10);

      expect(grid.columns, 2);
      expect(grid.tileWidth, greaterThan(0));
    });

    test('les marges latérales peuvent être imposées', () {
      final grid = cardGridMetrics(width: 400, gap: 10, padding: 0);

      expect(grid.tileWidth, closeTo((400 - 20) / 3, 0.001));
    });
  });
}

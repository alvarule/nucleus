/// Layout helpers scaled from a 390pt-wide design. Clamp avoids tiny/huge phones
/// blowing spacing out of range.
import 'package:flutter/widgets.dart';

/// Scales sizes from a 390pt design baseline.
class Scale {
  Scale._(this._factor);

  factory Scale.of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final factor = (width / 390).clamp(0.85, 1.25);
    return Scale._(factor);
  }

  final double _factor;

  double s(double value) => value * _factor;

  double get xs => s(4);
  double get sm => s(8);
  double get md => s(16);
  double get lg => s(24);
  double get xl => s(32);

  double get radiusSm => s(8);
  double get radiusMd => s(12);
  double get radiusLg => s(16);

  double get iconSm => s(18);
  double get iconMd => s(22);
  double get iconLg => s(28);

  double get fontSm => s(12);
  double get fontMd => s(14);
  double get fontLg => s(16);
  double get fontXl => s(22);
  double get fontHero => s(28);
}

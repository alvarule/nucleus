import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.assetName, {
    super.key,
    this.size,
    this.color,
  });

  final String assetName;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final resolved = size ?? scale.iconMd;
    return SvgPicture.asset(
      'assets/icons/$assetName.svg',
      width: resolved,
      height: resolved,
      colorFilter: ColorFilter.mode(
        color ?? context.colors.textPrimary,
        BlendMode.srcIn,
      ),
    );
  }
}

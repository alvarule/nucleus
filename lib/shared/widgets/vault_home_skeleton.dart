/// Full Home-body shimmer used only on the first vault list fetch.
/// Search, chips, and sort are placeholders so they cannot race with empty data.
import 'package:flutter/material.dart';
import 'package:nucleus/core/responsive/scale.dart';
import 'package:nucleus/core/theme/app_colors.dart';

class VaultHomeSkeleton extends StatefulWidget {
  const VaultHomeSkeleton({super.key});

  @override
  State<VaultHomeSkeleton> createState() => _VaultHomeSkeletonState();
}

class _VaultHomeSkeletonState extends State<VaultHomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final colors = context.colors;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return IgnorePointer(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(scale.md, 0, scale.md, scale.sm),
                child: _ShimmerBar(
                  height: scale.s(48),
                  radius: scale.radiusMd,
                  colors: colors,
                  t: _controller.value,
                ),
              ),
              SizedBox(
                height: scale.s(40),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: scale.md),
                  children: List.generate(
                    5,
                    (i) => Padding(
                      padding: EdgeInsets.only(right: scale.sm),
                      child: _ShimmerBar(
                        width: scale.s(i == 0 ? 56 : 88),
                        height: scale.s(36),
                        radius: scale.s(18),
                        colors: colors,
                        t: _controller.value,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: scale.sm),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(scale.md, 0, scale.md, scale.s(80)),
                  children: [
                    for (var s = 0; s < 3; s++) ...[
                      _ShimmerBar(
                        width: scale.s(120),
                        height: scale.s(14),
                        radius: scale.radiusSm,
                        colors: colors,
                        t: _controller.value,
                      ),
                      SizedBox(height: scale.md),
                      for (var r = 0; r < 2; r++) ...[
                        Row(
                          children: [
                            _ShimmerBar(
                              width: scale.s(44),
                              height: scale.s(44),
                              radius: scale.radiusSm,
                              colors: colors,
                              t: _controller.value,
                            ),
                            SizedBox(width: scale.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _ShimmerBar(
                                    width: scale.s(160),
                                    height: scale.s(14),
                                    radius: scale.radiusSm,
                                    colors: colors,
                                    t: _controller.value,
                                  ),
                                  SizedBox(height: scale.xs),
                                  _ShimmerBar(
                                    width: scale.s(100),
                                    height: scale.s(10),
                                    radius: scale.radiusSm,
                                    colors: colors,
                                    t: _controller.value,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: scale.lg),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  const _ShimmerBar({
    required this.colors,
    required this.t,
    required this.height,
    required this.radius,
    this.width,
  });

  final AppColors colors;
  final double t;
  final double height;
  final double radius;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final highlight = Color.lerp(colors.surfaceMuted, colors.surface, 0.85)!;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment(-1.0 + 2 * t, 0),
          end: Alignment(t * 2, 0),
          colors: [
            colors.surfaceMuted,
            highlight,
            colors.surfaceMuted,
          ],
        ),
      ),
    );
  }
}

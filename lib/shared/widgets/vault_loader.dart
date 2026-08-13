import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:nucleus/core/responsive/scale.dart';

class VaultLoader extends StatelessWidget {
  const VaultLoader({super.key, this.size});

  final double? size;

  @override
  Widget build(BuildContext context) {
    final scale = Scale.of(context);
    final dim = size ?? scale.s(96);
    return Center(
      child: Lottie.asset(
        'assets/animations/loading.json',
        width: dim,
        height: dim,
        fit: BoxFit.contain,
      ),
    );
  }
}

class VaultLoadingScaffold extends StatelessWidget {
  const VaultLoadingScaffold({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const VaultLoader(),
          if (message != null) ...[
            SizedBox(height: Scale.of(context).md),
            Text(message!),
          ],
        ],
      ),
    );
  }
}

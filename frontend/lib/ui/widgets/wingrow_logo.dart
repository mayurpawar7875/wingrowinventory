import 'package:flutter/material.dart';

class WingrowLogo extends StatelessWidget {
  final double size;
  const WingrowLogo({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/wingrow_logo.png',
      height: size,
      fit: BoxFit.contain,
    );
  }
}

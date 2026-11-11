import 'dart:ui';

import 'package:flutter/material.dart';

class LoginBackground extends StatelessWidget {
  const LoginBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [

        /// White
        Container(color: Colors.white),

        /// Blue blur top
        Positioned(
          top: -120,
          left: -100,
          child: _blurCircle(
            260,
            const Color(0xff2B8E65).withValues(alpha: .12),
          ),
        ),

        /// Right blur
        Positioned(
          top: 180,
          right: -120,
          child: _blurCircle(
            250,
            const Color(0xff2B8E65).withValues(alpha: .08),
          ),
        ),

        /// Bottom blur
        Positioned(
          bottom: -120,
          left: -80,
          child: _blurCircle(
            220,
            const Color(0xff2B8E65).withValues(alpha: .10),
          ),
        ),

        /// Top Right Hexagon
        const Positioned(
          top: 80,
          right: -40,
          child: Opacity(
            opacity: .07,
            child: Icon(
              Icons.hexagon,
              size: 220,
              color: const Color(0xFF1F7A55),
            ),
          ),
        ),

        /// Bottom Left Hexagon
        const Positioned(
          bottom: -20,
          left: -20,
          child: Opacity(
            opacity: .07,
            child: Icon(
              Icons.hexagon,
              size: 170,
              color: const Color(0xFF1F7A55),
            ),
          ),
        ),

        /// Dots left
        Positioned(
          top: 110,
          left: 10,
          child: _Dots(),
        ),

        /// Dots right bottom
        Positioned(
          bottom: 70,
          right: 12,
          child: _Dots(),
        ),
      ],
    );
  }

  Widget _blurCircle(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: 70,
        sigmaY: 70,
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        5,
            (i) => Row(
          children: List.generate(
            4,
                (j) => Container(
              margin: const EdgeInsets.all(5),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFF1F7A55).withValues(alpha: .18),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppAnimations {
  // Durations
  static const Duration screenEntranceDuration = Duration(milliseconds: 350);
  static const Duration listEntranceDuration = Duration(milliseconds: 400);
  static const Duration cardEntranceDuration = Duration(milliseconds: 300);
  static const Duration sheetEntranceDuration = Duration(milliseconds: 300);
  static const Duration dialogEntranceDuration = Duration(milliseconds: 250);
  static const Duration refreshDuration = Duration(milliseconds: 250);
  static const Duration skeletonDuration = Duration(milliseconds: 1200);

  // Curves
  static const Curve easeOutCubic = Curves.easeOutCubic;

  // Stagger delays
  static Duration getDelayForIndex(int index, {int stepMs = 40}) {
    return Duration(milliseconds: index * stepMs);
  }
}

extension AppAnimateExtension on Widget {
  // Screen Entrance Animation (Fade In + Slight Slide Up)
  Widget animateScreenEntrance() {
    return animate()
        .fadeIn(duration: AppAnimations.screenEntranceDuration)
        .slideY(
          begin: 0.05,
          end: 0,
          duration: AppAnimations.screenEntranceDuration,
          curve: AppAnimations.easeOutCubic,
        );
  }

  // Section Stagger Animation
  Widget animateSectionEntrance({int index = 0}) {
    return animate(delay: Duration(milliseconds: index * 100))
        .fadeIn(duration: AppAnimations.screenEntranceDuration)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: AppAnimations.screenEntranceDuration,
          curve: AppAnimations.easeOutCubic,
        );
  }

  // Card Animation System (Fade In + Scale)
  Widget animateCardEntrance() {
    return animate()
        .fadeIn(duration: AppAnimations.cardEntranceDuration)
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: AppAnimations.cardEntranceDuration,
          curve: AppAnimations.easeOutCubic,
        );
  }

  // Staggered list element animation (Vertical Lists)
  Widget animateListEntrance(int index) {
    final delay = Duration(milliseconds: index * 40);
    return animate(delay: delay)
        .fadeIn(duration: AppAnimations.listEntranceDuration)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: AppAnimations.listEntranceDuration,
          curve: AppAnimations.easeOutCubic,
        );
  }

  // Horizontal List Item Animation
  Widget animateHorizontalListEntrance(int index) {
    final delay = Duration(milliseconds: index * 25);
    return animate(delay: delay)
        .fadeIn(duration: AppAnimations.screenEntranceDuration)
        .slideX(
          begin: 0.15,
          end: 0,
          duration: AppAnimations.screenEntranceDuration,
          curve: AppAnimations.easeOutCubic,
        );
  }
  
  // Empty State Animation
  Widget animateEmptyState() {
    return animate()
        .fadeIn(duration: AppAnimations.screenEntranceDuration)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: AppAnimations.screenEntranceDuration,
          curve: AppAnimations.easeOutCubic,
        );
  }
}

class PremiumPageTransitionsBuilder extends PageTransitionsBuilder {
  const PremiumPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
    );
  }
}

# ANIMATION_SYSTEM_GUIDE.md

# Global Animation & Motion Design System

## Overview

This document defines the animation system for the entire Flutter application.

The objective is to create a modern, premium, and consistent user experience comparable to high-quality applications such as Airbnb, Telegram, Sofascore, Notion, Google Photos, and Material 3 apps.

The implementation must rely on:

* flutter_animate
* Flutter Hero animations
* Native Flutter transitions

The goal is to improve perceived performance and visual quality without affecting business logic or existing UI layouts.

---

# Core Principles

Animations must:

* Feel smooth and natural
* Improve user focus
* Enhance navigation flow
* Remain lightweight and performant
* Never distract the user

Prioritize:

* Fade animations
* Slide animations
* Scale animations
* Hero transitions

Avoid:

* Bounce effects
* Elastic animations
* Rotation effects
* Excessive zooming
* Over-animated interfaces

---

# Required Package

```yaml
flutter_animate: ^4.5.2
```

---

# Global Screen Entrance Animation

Every screen in the application should animate on first appearance.

Animation:

* Fade In
* Slight Slide Up

Configuration:

```dart
fadeIn(
  duration: 350.ms,
)
.slideY(
  begin: 0.05,
  end: 0,
  duration: 350.ms,
  curve: Curves.easeOutCubic,
)
```

Rules:

* Run once when entering the screen.
* Do not replay unnecessarily.
* Apply to all major screens.

---

# Section Stagger Animation

All screen sections should appear sequentially.

Example:

1. Header
2. Filters
3. Statistics
4. Featured Content
5. Lists
6. Additional Sections

Recommended delays:

| Section | Delay |
| ------- | ----- |
| 1       | 0ms   |
| 2       | 100ms |
| 3       | 200ms |
| 4       | 300ms |
| 5       | 400ms |
| 6       | 500ms |

Animation:

```dart
.fadeIn()
.slideY(begin: 0.08)
```

---

# Vertical List Animation

Apply to:

* ListView
* SliverList
* Infinite Lists
* Search Results
* Match Lists
* News Lists
* Player Lists
* Team Lists

Animation:

```dart
Animate(
  effects: [
    FadeEffect(
      duration: 400.ms,
      delay: (index * 40).ms,
    ),
    SlideEffect(
      begin: Offset(0, 0.08),
      end: Offset.zero,
      duration: 400.ms,
      delay: (index * 40).ms,
    ),
  ],
)
```

Rules:

* Staggered appearance.
* Keep motion subtle.
* Maintain smooth scrolling performance.

---

# Horizontal List Animation

Apply to:

* Category selectors
* Date pickers
* Horizontal cards
* Carousels

Animation:

```dart
.animate(
  delay: (index * 25).ms,
)
.fadeIn(
  duration: 350.ms,
)
.slideX(
  begin: 0.15,
  end: 0,
)
```

---

# Card Animation System

Apply to:

* Match Cards
* Team Cards
* News Cards
* Tournament Cards
* Dashboard Cards
* Settings Cards

Animation:

```dart
.animate()
.fadeIn(
  duration: 300.ms,
)
.scale(
  begin: Offset(0.97, 0.97),
  end: Offset(1, 1),
)
```

Rules:

* Keep scaling subtle.
* No bounce effects.
* No aggressive motion.

---

# Hero Image Transition System

Hero animations must be implemented globally.

Apply to:

* News images
* Player photos
* Team logos
* Tournament banners
* Match thumbnails
* Gallery images
* Any image leading to another screen

Example:

```dart
Hero(
  tag: 'player_${player.id}',
  child: CachedNetworkImage(...),
)
```

Rules:

* Every Hero tag must be unique.
* Prefer ID-based tags.
* Ensure smooth transitions between screens.

---

# Fullscreen Image Viewer

Any tappable image should support fullscreen viewing.

Transition:

```dart
Hero(
  tag: imageTag,
)
```

Requirements:

* Hero transition
* Fade background animation
* Black immersive background
* Smooth open animation
* Smooth close animation
* Preserve aspect ratio
* Support zoom if already available

Expected UX:

* Similar to Telegram
* Similar to Google Photos
* Similar to X (Twitter)

---

# Enhanced Hero Animations

For large media content:

Combine:

* Hero
* Fade In
* Subtle Scale

Animation:

```dart
.fadeIn(
  duration: 300.ms,
)
.scale(
  begin: Offset(0.95, 0.95),
  end: Offset(1, 1),
)
```

---

# Statistics & Dashboard Animations

Apply to:

* Stats cards
* Analytics widgets
* Dashboard blocks
* Performance metrics

Animation:

```dart
.fadeIn()
.slideY(begin: 0.08)
```

Duration:

```text
350ms
```

---

# Bottom Sheet Animation

Opening:

```dart
Slide From Bottom
+
Fade In
```

Duration:

```text
300ms
```

Curve:

```dart
Curves.easeOutCubic
```

Closing:

* Reverse smoothly

---

# Dialog Animation

Opening:

```dart
Fade
+
Scale
```

Scale:

```text
0.95 → 1.0
```

Duration:

```text
250ms
```

Closing:

* Reverse animation

---

# Navigation Transition System

Create a unified route transition system.

Preferred Transition:

```text
Fade Through Transition
```

Duration:

```text
250ms
```

Apply consistently throughout the application.

Avoid:

* Rotation transitions
* Bounce transitions
* Elastic transitions
* Large zoom transitions

---

# Loading State Animation

Apply to:

* Skeleton loaders
* Placeholder widgets

Animation:

```dart
Fade Animation
```

Duration:

```text
1200ms
```

Repeat smoothly.

Avoid expensive effects that may impact performance.

---

# Pull To Refresh Animation

After refresh completes:

```dart
Fade Transition
```

Duration:

```text
250ms
```

Keep the effect minimal.

---

# Empty State Animation

Apply to:

* Empty search results
* No data screens
* Empty lists

Animation:

```dart
.fadeIn()
.slideY(begin: 0.08)
```

Duration:

```text
350ms
```

---

# Performance Rules

Never animate:

* Every Text widget
* Small icons
* AppBar buttons
* Tiny UI components
* Frequently rebuilding widgets

Only animate:

* Screens
* Sections
* Cards
* Lists
* Images
* Major content blocks

---

# Centralized Animation Architecture

Create:

```text
lib/core/animations/app_animations.dart
```

This file should contain:

* Animation durations
* Animation delays
* Curves
* Reusable extensions
* Reusable animation builders
* Hero helpers
* Route transition helpers

Requirements:

* No duplicated animation logic
* No scattered hardcoded values
* Single source of truth

---

# Code Quality Requirements

* Follow Flutter best practices
* Keep animations reusable
* Avoid unnecessary rebuilds
* Maintain 60 FPS performance
* Preserve current architecture
* Preserve business logic
* Preserve UI layouts

---

# Final Expected Result

✅ Every screen has a polished entrance animation

✅ All lists use staggered animations

✅ Cards have premium micro-interactions

✅ Images use Hero transitions

✅ Fullscreen image viewing supports Hero animations

✅ Navigation transitions are unified

✅ BottomSheets animate consistently

✅ Dialogs animate consistently

✅ Animation logic is centralized

✅ No UI redesign

✅ No business logic changes

✅ The application feels significantly more modern, premium, and professional while maintaining excellent performance

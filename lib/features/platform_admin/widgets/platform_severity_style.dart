import 'package:flutter/material.dart';
import 'package:syriacosmeticsmanger/features/platform_admin/domain/models/platform_admin_alert_models.dart';

/// How an alert's severity looks: the same colour and icon wherever it is shown,
/// so that a count on a market card and an alert in the list read as one thing.
/// The colour is never the only sign: the words are beside it.
abstract final class PlatformSeverityStyle {
  static Color color(BuildContext context, String severity) => switch (severity) {
        PlatformSeverity.critical => Theme.of(context).colorScheme.error,
        PlatformSeverity.warning => Colors.amber.shade800,
        _ => Theme.of(context).primaryColor,
      };

  static IconData icon(String severity) => switch (severity) {
        PlatformSeverity.critical => Icons.priority_high_rounded,
        PlatformSeverity.warning => Icons.warning_amber_rounded,
        _ => Icons.info_outline,
      };
}

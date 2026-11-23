import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One step of the test job: what it is called, what guards it, and what it runs.
class _Step {
  const _Step({required this.name, required this.guard, required this.command});

  final String name;
  final String? guard;
  final String command;

  /// A step that runs the whole suite: `flutter test` with no path after it.
  bool get isWholeRun => RegExp(r'^flutter test(\s+--dart-define=\S+)*\s*$').hasMatch(command);

  /// A step that runs named test files or folders: `flutter test <paths>`.
  bool get isNamedRun => command.startsWith('flutter test') && !isWholeRun;

  /// Whether the step runs even after an earlier step has failed. Without a
  /// guard GitHub's default is `success()`, so the step is skipped instead.
  bool get runsAfterAFailure =>
      guard != null && (guard!.contains('always()') || guard!.contains('!cancelled()'));
}

/// The steps of the `analyze-and-test` job, in the order the file puts them.
///
/// Read line by line rather than through a YAML package: `yaml` is only a
/// transitive dependency here and the job's shape is fixed, so a reader costs
/// nothing and keeps `pubspec.yaml` untouched.
List<_Step> _testJobSteps() {
  final List<String> lines = File('.github/workflows/ci.yml').readAsLinesSync();
  final int jobAt = lines.indexWhere((String line) => line.startsWith('  analyze-and-test:'));
  expect(jobAt, isNonNegative, reason: 'the analyze-and-test job is gone');

  final List<_Step> steps = <_Step>[];
  String? name;
  String? guard;
  final List<String> command = <String>[];
  bool inCommand = false;

  void close() {
    if (name != null) {
      steps.add(_Step(name: name!, guard: guard, command: command.join('\n').trim()));
    }
    name = null;
    guard = null;
    command.clear();
    inCommand = false;
  }

  for (final String line in lines.skip(jobAt + 1)) {
    // A line at two spaces of indent that is not blank starts the next job.
    if (line.trimLeft().isNotEmpty && !line.startsWith('   ') && line.startsWith('  ')) {
      break;
    }

    final RegExpMatch? startsStep = RegExp(r'^      - name: (.*)$').firstMatch(line);
    if (startsStep != null) {
      close();
      name = startsStep.group(1)!.trim();
      continue;
    }
    if (name == null) {
      continue;
    }

    final RegExpMatch? hasGuard = RegExp(r'^        if: (.*)$').firstMatch(line);
    if (hasGuard != null) {
      guard = hasGuard.group(1)!.trim();
      inCommand = false;
      continue;
    }

    final RegExpMatch? hasCommand = RegExp(r'^        run: \|?(.*)$').firstMatch(line);
    if (hasCommand != null) {
      inCommand = true;
      final String first = hasCommand.group(1)!.trim();
      if (first.isNotEmpty) {
        command.add(first);
      }
      continue;
    }

    // Another key of the same step ends the command block.
    if (RegExp(r'^        [a-zA-Z_-]+:').hasMatch(line)) {
      inCommand = false;
      continue;
    }
    // Comments inside a command block describe it; they are not commands.
    if (inCommand && line.trim().isNotEmpty && !line.trim().startsWith('#')) {
      command.add(line.trim());
    }
  }
  close();

  return steps;
}

void main() {
  group('the test job of the workflow', () {
    late List<_Step> steps;

    setUp(() => steps = _testJobSteps());

    test('is read at all: it has the named feature steps and one whole run', () {
      expect(steps.where((_Step step) => step.isWholeRun).length, 1,
          reason: 'exactly one step runs the whole suite');
      expect(steps.where((_Step step) => step.isNamedRun).length, greaterThan(20),
          reason: 'the named feature steps are read');
    });

    // K-15 criterion 4. The ordering held when it was measured by hand; nothing
    // stopped the next step from being appended after the whole run and undoing
    // it silently, because a step added there still passes CI.
    test('runs every named feature step BEFORE the whole run (K-15)', () {
      final int wholeRunAt = steps.indexWhere((_Step step) => step.isWholeRun);
      final List<String> afterTheWholeRun = steps
          .skip(wholeRunAt + 1)
          .where((_Step step) => step.isNamedRun)
          .map((_Step step) => step.name)
          .toList();

      expect(afterTheWholeRun, isEmpty,
          reason: 'a named feature step must report before the whole run, not after it');
    });

    test('keeps the whole run last, so nothing can be appended behind it', () {
      expect(steps.last.isWholeRun, isTrue,
          reason: 'the whole run is the last step of the job: ${steps.last.name}');
    });

    // Every named step carries `always()`, so one red step does not hide the
    // rest. The whole run had no guard, so its default was `success()`: any one
    // of the named steps failing skipped it, and the suite's figures — how many
    // tests fail, and which — vanished from the run with it.
    test('reports the whole suite even when a named step before it is red', () {
      final _Step wholeRun = steps.firstWhere((_Step step) => step.isWholeRun);

      expect(wholeRun.runsAfterAFailure, isTrue,
          reason: 'the whole run must not be skipped by a red step above it; its guard is ${wholeRun.guard}');
    });

    test('reports every named feature step even when one before it is red', () {
      final List<String> skippable = steps
          .where((_Step step) => step.isNamedRun && !step.runsAfterAFailure)
          .map((_Step step) => step.name)
          .toList();

      expect(skippable, isEmpty, reason: 'these named steps would be skipped by an earlier failure');
    });
  });
}

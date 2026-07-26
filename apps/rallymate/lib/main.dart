import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';

/// Opt-in on-device frame profiler. Active ONLY with
/// `--dart-define=RALLYMATE_FRAME_LOG=1`; disabled (zero cost) otherwise, so it
/// never ships in production builds.
///
/// It aggregates UI build and GPU raster durations in-memory and appends ONE
/// compact summary line every 2 seconds (grep-friendly `RMFRAME|` prefix) to
/// `<app external files>/rmframe.log`. A file sink is used instead of
/// `print`/`debugPrint` because in profile/AOT builds Dart stdout is not routed
/// to Android logcat and `debugPrint` throttles (~1KB/s) at 60–120fps. The file
/// lives under the app-specific external dir, which `adb` can read directly:
/// `adb shell cat /sdcard/Android/data/com.rallymate.rallymate/files/rmframe.log`.
/// We roll up percentiles (p50/p90/p99) and the count of frames over the
/// 16.67ms (60Hz) and 33ms budgets.
///
/// Note: `bool.fromEnvironment` only accepts the literal "true", so we read the
/// raw string and accept both `1` and `true`.
const String _frameLogRaw = String.fromEnvironment('RALLYMATE_FRAME_LOG');
const bool _frameLog = _frameLogRaw == '1' || _frameLogRaw == 'true';

class _FrameStats {
  final List<double> build = <double>[];
  final List<double> raster = <double>[];
  final List<double> total = <double>[];

  void add(FrameTiming t) {
    build.add(t.buildDuration.inMicroseconds / 1000.0);
    raster.add(t.rasterDuration.inMicroseconds / 1000.0);
    total.add(t.totalSpan.inMicroseconds / 1000.0);
  }

  void clear() {
    build.clear();
    raster.clear();
    total.clear();
  }

  static double _pct(List<double> xs, double p) {
    if (xs.isEmpty) return 0;
    final sorted = List<double>.from(xs)..sort();
    final idx = ((sorted.length - 1) * p).round();
    return sorted[idx];
  }

  static int _over(List<double> xs, double budget) =>
      xs.where((v) => v > budget).length;

  String summarize() {
    final n = total.length;
    if (n == 0) return 'RMFRAME|frames=0 (idle)';
    return 'RMFRAME|frames=$n'
        '|build_p50=${_pct(build, 0.50).toStringAsFixed(2)}'
        '|build_p90=${_pct(build, 0.90).toStringAsFixed(2)}'
        '|build_p99=${_pct(build, 0.99).toStringAsFixed(2)}'
        '|raster_p50=${_pct(raster, 0.50).toStringAsFixed(2)}'
        '|raster_p90=${_pct(raster, 0.90).toStringAsFixed(2)}'
        '|raster_p99=${_pct(raster, 0.99).toStringAsFixed(2)}'
        '|total_p50=${_pct(total, 0.50).toStringAsFixed(2)}'
        '|total_p90=${_pct(total, 0.90).toStringAsFixed(2)}'
        '|total_p99=${_pct(total, 0.99).toStringAsFixed(2)}'
        '|over16=${_over(total, 16.67)}'
        '|over33=${_over(total, 33.0)}';
  }
}

Future<void> _startFrameLog() async {
  final stats = _FrameStats();
  SchedulerBinding.instance.addTimingsCallback((timings) {
    for (final timing in timings) {
      stats.add(timing);
    }
  });
  IOSink? sink;
  try {
    // Internal app documents dir (`app_flutter`) so a debuggable profile build
    // can be read back via `adb shell run-as com.rallymate.rallymate cat
    // app_flutter/rmframe.log`. The external dir is unreadable by adb on
    // Android 11+ scoped storage.
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/rmframe.log');
    sink = file.openWrite(mode: FileMode.write);
    sink.writeln('RMFRAME|start ts=${DateTime.now().toIso8601String()}');
    await sink.flush();
  } catch (_) {
    sink = null;
  }
  Timer.periodic(const Duration(seconds: 2), (_) {
    final line = stats.summarize();
    stats.clear();
    sink?.writeln(line);
    sink?.flush();
  });
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (_frameLog) {
    unawaited(_startFrameLog());
  }
  runApp(const ProviderScope(child: RallyMateApp()));
}

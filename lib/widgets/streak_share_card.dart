import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/habit.dart';
import '../services/streak_calculator.dart';

/// A visual summary card for a habit's streak — current streak, best
/// streak, and score — meant to be captured as an image and shared.
/// Rendered off-screen (wrapped in an [Offstage] + [RepaintBoundary] by
/// the caller) so it never actually shows in the UI; [shareStreakCard]
/// captures it on demand.
class StreakShareCard extends StatelessWidget {
  final Habit habit;
  final StreakResult streak;

  const StreakShareCard({
    super.key,
    required this.habit,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [habit.color, habit.color.withValues(alpha: 0.6)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  radius: 22,
                  child: Icon(habit.icon, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    habit.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.local_fire_department,
                    color: Colors.white, size: 40),
                const SizedBox(width: 8),
                Text(
                  '${streak.currentStreak}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ],
            ),
            Text(
              'day streak',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatColumn(label: 'Best streak', value: '${streak.bestStreak}'),
                _StatColumn(label: 'Streak score', value: '${streak.score}'),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'HABITS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
      ],
    );
  }
}

/// Captures whatever [boundaryKey] is currently attached to (a
/// [RepaintBoundary] wrapping a [StreakShareCard]) as a PNG and opens
/// the platform share sheet for it.
Future<void> shareStreakCard(
  GlobalKey boundaryKey,
  Habit habit,
  StreakResult streak,
) async {
  final boundary = boundaryKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) return;

  final image = await boundary.toImage(pixelRatio: 3);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return;
  final bytes = byteData.buffer.asUint8List();

  final dir = await getTemporaryDirectory();
  final safeName = habit.name.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
  final file =
      File('${dir.path}/streak_${safeName.isEmpty ? 'habit' : safeName}.png');
  await file.writeAsBytes(bytes, flush: true);

  await Share.shareXFiles(
    [XFile(file.path)],
    text: 'My "${habit.name}" streak: ${streak.currentStreak} days.',
  );
}

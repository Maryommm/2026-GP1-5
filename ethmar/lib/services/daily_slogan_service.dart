import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How many approved Home slogans there are (homeSlogan1..3 in app_strings).
const sloganCount = 3;

/// Today's slogan index, shared by Home (like `currentUsername`), so
/// rebuilding Home or switching language never picks a new one.
/// Null until the first lookup finishes.
final ValueNotifier<int?> dailySloganIndex = ValueNotifier(null);

/// Picks one Home slogan per local calendar day and keeps it on the device.
///
/// * Same day: the stored slogan is reused, even after the app restarts.
/// * New day: a random slogan is picked, never the one shown last time.
/// * Only the index is stored, so the slogan shows in whichever language
///   the app is using.
class DailySloganService {
  DailySloganService({
    DateTime Function()? clock,
    Random? random,
    ValueNotifier<int?>? notifier,
  })  : _clock = clock ?? DateTime.now,
        _random = random ?? Random(),
        _notifier = notifier ?? dailySloganIndex;

  static const _indexKey = 'daily_slogan_index';
  static const _dateKey = 'daily_slogan_date';

  final DateTime Function() _clock;
  final Random _random;
  final ValueNotifier<int?> _notifier;

  /// Local date of the index we already have, so most checks need no read.
  String? _date;

  /// The lookup in progress, if any. Every caller shares it, so the midnight
  /// timer, app resume and Home opening can never pick or save twice.
  Future<int>? _pending;

  /// Local calendar date as "YYYY-MM-DD".
  static String localDate(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';

  /// Makes sure [dailySloganIndex] holds today's slogan and returns it.
  Future<int> refresh() {
    final today = localDate(_clock());
    final current = _notifier.value;
    if (_date == today && current != null) return Future.value(current);
    return _pending ??= _load(today).whenComplete(() => _pending = null);
  }

  Future<int> _load(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_dateKey);
    final storedIndex = prefs.getInt(_indexKey);
    final hasValidIndex =
        storedIndex != null && storedIndex >= 0 && storedIndex < sloganCount;

    final int index;
    if (hasValidIndex && storedDate == today) {
      index = storedIndex;
    } else {
      // Never repeat the slogan shown last time.
      final candidates = [
        for (var i = 0; i < sloganCount; i++)
          if (!hasValidIndex || i != storedIndex) i,
      ];
      index = candidates[_random.nextInt(candidates.length)];
      await prefs.setInt(_indexKey, index);
      await prefs.setString(_dateKey, today);
    }

    _date = today;
    _notifier.value = index;
    return index;
  }
}

/// The one service the app uses, so its memory of today is shared.
final dailySloganService = DailySloganService();

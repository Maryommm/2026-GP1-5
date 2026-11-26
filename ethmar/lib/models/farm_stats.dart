/// The user's streak and how many lands their farm has.
///
/// Stats summary: `users/{uid}/stats/summary`
///   - currentStreak      int          days in a row with all tasks done
///   - lastCompletedDate  String|null  "yyyy-mm-dd" of the last such day
///                                     (see TaskLog.dateKey); null if none
///   - lands              int          1-9
///
/// This is saved separately from `users/{uid}`, because the rules only
/// allow the 4 profile fields there.
library;

class FarmStats {
  const FarmStats({
    this.currentStreak = 0,
    this.lastCompletedDate,
    this.lands = 1,
  });

  /// The document name inside `users/{uid}/stats`.
  static const docId = 'summary';

  final int currentStreak;
  final String? lastCompletedDate;
  final int lands;

  Map<String, Object?> toMap() => {
    'currentStreak': currentStreak,
    'lastCompletedDate': lastCompletedDate,
    'lands': lands,
  };

  /// Throws a [FormatException] if the saved values are not valid.
  factory FarmStats.fromMap(Map<String, dynamic> data) {
    final currentStreak = data['currentStreak'];
    final lastCompletedDate = data['lastCompletedDate'];
    final lands = data['lands'];
    if (currentStreak is! int ||
        currentStreak < 0 ||
        (lastCompletedDate != null && lastCompletedDate is! String) ||
        lands is! int ||
        lands < 1 ||
        lands > 9) {
      throw FormatException('Invalid farm stats: $data');
    }
    return FarmStats(
      currentStreak: currentStreak,
      lastCompletedDate: lastCompletedDate as String?,
      lands: lands,
    );
  }
}

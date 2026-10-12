import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/farm_plant.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// A schedule while it's being edited; [on] is false until the user turns
/// the reminder on.
class ScheduleDraft {
  ScheduleDraft(this.repeat, this.time);

  /// Starts from a saved schedule, or from [repeat] at [time] (turned off)
  /// when there isn't one yet.
  ScheduleDraft.from(CareSchedule? saved, Repeat repeat, TimeOfDay time)
    : on = saved != null,
      repeat = saved?.repeat ?? repeat,
      time = saved?.time ?? time;

  bool on = false;
  Repeat repeat;
  TimeOfDay time;

  CareSchedule? get result => on ? CareSchedule(repeat, time) : null;
}

/// White card with the irrigation and fertilization schedules from the
/// sketch, each with its own on/off switch. Used when adding a plant and
/// when editing one.
class CareScheduleCard extends StatelessWidget {
  const CareScheduleCard({
    super.key,
    required this.irrigation,
    required this.fertilization,
    required this.onChanged,
  });
  final ScheduleDraft irrigation;
  final ScheduleDraft fertilization;

  /// Called after either draft changes, so the screen can rebuild.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScheduleSection(
            title: s.schedIrrigation,
            icon: Icons.water_drop_rounded,
            draft: irrigation,
            onChanged: onChanged,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.border),
          ),
          _ScheduleSection(
            title: s.schedFertilization,
            icon: Icons.spa_rounded,
            draft: fertilization,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// One schedule from the sketch: title with an on/off switch; when on,
/// the repetition (with − / +) and the alarm time.
class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({
    required this.title,
    required this.icon,
    required this.draft,
    required this.onChanged,
  });
  final String title;
  final IconData icon;
  final ScheduleDraft draft;
  final VoidCallback onChanged;

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: draft.time,
    );
    if (picked == null) return;
    draft.time = picked;
    onChanged();
  }

  void _step(int by) {
    draft.repeat = Repeat.values[draft.repeat.index + by];
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final loc = MaterialLocalizations.of(context);
    final t = draft.time;
    final period = t.period == DayPeriod.am
        ? loc.anteMeridiemAbbreviation
        : loc.postMeridiemAbbreviation;
    final index = draft.repeat.index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MergeSemantics(
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.seaTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: AppColors.seaDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppText.label(context)
                      .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Switch(
                value: draft.on,
                activeTrackColor: AppColors.forest,
                onChanged: (v) {
                  draft.on = v;
                  onChanged();
                },
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !draft.on
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        16,
                        10,
                        8,
                        10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.forestTint,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.schedRepetition,
                                  style: AppText.small(
                                    context,
                                    color: AppColors.forest,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 150),
                                  child: Text(
                                    draft.repeat.label(s),
                                    key: ValueKey(draft.repeat),
                                    style: AppText.label(context).copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _SquareButton(
                            icon: Icons.add_rounded,
                            tooltip: s.schedLessOften,
                            onPressed: index < Repeat.values.length - 1
                                ? () => _step(1)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          _SquareButton(
                            icon: Icons.remove_rounded,
                            tooltip: s.schedMoreOften,
                            onPressed: index > 0 ? () => _step(-1) : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.schedAlarmTime,
                      style: AppText.small(
                        context,
                        color: AppColors.forest,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _TimeBox(
                          text: '${loc.formatHour(t)}:${loc.formatMinute(t)}',
                          width: 110,
                          onTap: () => _pickTime(context),
                        ),
                        const SizedBox(width: 8),
                        _TimeBox(text: period, onTap: () => _pickTime(context)),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// The white + / − buttons on the repetition row.
class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.forest,
        disabledBackgroundColor: AppColors.surface.withValues(alpha: 0.5),
        disabledForegroundColor: AppColors.textHint,
      ),
      icon: Icon(icon),
    );
  }
}

/// A tinted box showing part of the alarm time; tapping opens the picker.
class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.text, required this.onTap, this.width});
  final String text;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forestTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
          constraints: const BoxConstraints(minWidth: 52, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(
            text,
            // Times read left to right in Arabic too.
            textDirection: TextDirection.ltr,
            style: AppText.label(context)
                .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

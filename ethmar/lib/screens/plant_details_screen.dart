import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/farm_plant.dart';
import '../services/farm_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart' show showEthmarToast;
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_header.dart';
import '../widgets/page_routes.dart';
import 'edit_plant_screen.dart';

/// One plant, from the sketch: its picture, days since planting and
/// watering, the growth timeline (pictures with notes and dates), and the
/// care schedule with an Edit button.
///
/// [index] is the plant's number on the farm (see [FarmStore]).
class PlantDetailsScreen extends StatelessWidget {
  const PlantDetailsScreen({super.key, required this.index});
  final int index;

  /// "Upload a picture": pick where it comes from, then add optional notes.
  Future<void> _addPicture(BuildContext context, FarmPlant plant) async {
    final s = S.of(context);
    final picked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TODO(photo): Open the camera / gallery and keep the
              //   picture. Prototype: both just move on to the notes.
              _SourceTile(
                icon: Icons.photo_camera_rounded,
                label: s.takePhoto,
                onTap: () => Navigator.of(context).pop(true),
              ),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: s.chooseFromGallery,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != true || !context.mounted) return;
    final notes = await showDialog<String>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => const _NotesDialog(),
    );
    if (notes == null || !context.mounted) return;
    // TODO(backend): Upload the picture and save the entry for this plant.
    FarmStore.updatePlant(
      index,
      plant.withGrowth(
        GrowthEntry(date: DateTime.now(), notes: notes.isEmpty ? null : notes),
      ),
    );
    showEthmarToast(context, s.pictureAdded);
  }

  Future<void> _edit(BuildContext context) async {
    final saved = await Navigator.of(context)
        .push<bool>(riseRoute(EditPlantScreen(index: index)));
    if (saved == true && context.mounted) {
      showEthmarToast(context, S.of(context).plantUpdated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: LeafPrintBackground(
        child: ValueListenableBuilder<List<FarmPlant>>(
          valueListenable: FarmStore.plants,
          builder: (context, plants, _) {
            final plant = plants[index];
            final crop = plant.crop;
            final irrigation = plant.irrigation;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EthmarPageHeader(
                  title: plant.name,
                  accent: crop.name.of(context),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      Entrance(
                        child: Container(
                          height: 170,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: crop.category.tint,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Image.asset(crop.image, cacheWidth: 400),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: s.daysSincePlanting,
                              value: s.plantAge(plant.daysSincePlanting),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: s.summaryIrrigation,
                              value: irrigation == null
                                  ? s.summaryNotSet
                                  : irrigation.repeat.label(s),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Panel(
                        title: s.stagesTitle,
                        child: _GrowthTimeline(
                          entries: plant.growth,
                          onAdd: () => _addPicture(context, plant),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Panel(
                        title: s.careSchedule,
                        action: _SmallButton(
                          label: s.edit,
                          icon: Icons.edit_rounded,
                          onPressed: () => _edit(context),
                        ),
                        child: _ScheduleRows(plant: plant),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

/// Small white box: a label on top, the value below (from the sketch).
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.small(context)),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppText.label(context)
                  .copyWith(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// White rounded card with a title (and an optional button beside it).
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final a = action;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppText.label(context)
                      .copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              ?a,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Small forest pill, like "Upload a picture" and "Edit" in the sketch.
class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.forest,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        splashColor: const Color(0x22FFFFFF),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 16, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.onForest),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppText.button(context).copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The growth timeline: oldest at the top, a dot and line down the side,
/// then the "Upload a picture" button.
class _GrowthTimeline extends StatelessWidget {
  const _GrowthTimeline({required this.entries, required this.onAdd});
  final List<GrowthEntry> entries;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final loc = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entries.isEmpty)
          Row(
            children: [
              const _PhotoFrame(),
              const SizedBox(width: 14),
              Expanded(
                child: Text(s.stagesEmpty, style: AppText.small(context)),
              ),
            ],
          )
        else
          for (var i = 0; i < entries.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TimelineRail(first: i == 0, last: i == entries.length - 1),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: const _PhotoFrame(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entries[i].notes ?? '—',
                            style: AppText.label(context).copyWith(
                              color: entries[i].notes == null
                                  ? AppColors.textSecondary
                                  : AppColors.forest,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            loc.formatMediumDate(entries[i].date),
                            style: AppText.small(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 14),
        Center(
          child: _SmallButton(
            label: s.uploadPicture,
            icon: Icons.add_a_photo_rounded,
            onPressed: onAdd,
          ),
        ),
      ],
    );
  }
}

/// The dot and line beside each timeline entry.
class _TimelineRail extends StatelessWidget {
  const _TimelineRail({required this.first, required this.last});
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      child: Column(
        children: [
          Container(
            width: 2,
            height: 10,
            color: first ? Colors.transparent : AppColors.forest,
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.forest,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              width: 2,
              color: last ? Colors.transparent : AppColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}

/// A picture on the timeline: the sketch's dotted square.
/// TODO(photo): Show the entry's picture inside the frame.
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _DottedFrame(),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.forestTint,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.image_outlined,
          color: AppColors.forest,
          size: 28,
        ),
      ),
    );
  }
}

class _DottedFrame extends CustomPainter {
  const _DottedFrame();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.forest.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(14),
        ),
      );
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 5) {
        canvas.drawPath(metric.extractPath(d, d + 1.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DottedFrame oldDelegate) => false;
}

/// The care schedule rows: task on one side, how often and when it's next
/// due on the other.
class _ScheduleRows extends StatelessWidget {
  const _ScheduleRows({required this.plant});
  final FarmPlant plant;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      children: [
        _ScheduleRow(
          icon: Icons.water_drop_rounded,
          task: s.summaryIrrigation,
          schedule: plant.irrigation,
          plantedAt: plant.plantedAt,
        ),
        const Divider(height: 24, color: AppColors.border),
        _ScheduleRow(
          icon: Icons.spa_rounded,
          task: s.summaryFertilization,
          schedule: plant.fertilization,
          plantedAt: plant.plantedAt,
        ),
      ],
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.icon,
    required this.task,
    required this.schedule,
    required this.plantedAt,
  });
  final IconData icon;
  final String task;
  final CareSchedule? schedule;
  final DateTime plantedAt;

  /// "Today, 7:00 AM", "Tomorrow, 7:00 AM" or "Wed, Oct 9, 7:00 AM".
  String _when(BuildContext context, DateTime next) {
    final s = S.of(context);
    final loc = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(next.year, next.month, next.day);
    final time = loc.formatTimeOfDay(TimeOfDay.fromDateTime(next));
    final date = switch (day.difference(today).inDays) {
      0 => s.today,
      1 => s.tomorrow,
      _ => loc.formatMediumDate(next),
    };
    return '$date, $time';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final c = schedule;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.seaTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.seaDeep),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                task,
                style: AppText.label(context)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  c == null ? s.summaryNotSet : c.repeat.label(s),
                  textAlign: TextAlign.end,
                  style:
                      AppText.label(
                        context,
                        color: c == null ? AppColors.textSecondary : null,
                      ).copyWith(
                        fontWeight: c == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                ),
                if (c != null)
                  Text(
                    s.scheduleNext(
                      _when(context, c.nextAfter(plantedAt, DateTime.now())),
                    ),
                    textAlign: TextAlign.end,
                    style: AppText.small(context),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, color: AppColors.forest),
      title: Text(label, style: AppText.label(context).copyWith(fontSize: 16)),
      onTap: onTap,
    );
  }
}

/// After choosing a picture: optional notes for this growth stage.
/// Pops with the notes ('' when left empty), or null on cancel.
class _NotesDialog extends StatefulWidget {
  const _NotesDialog();

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: _PhotoFrame()),
            const SizedBox(height: 14),
            Text(
              s.notesTitle,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 14),
            EthmarTextField(
              label: s.notesLabel,
              hint: s.notesHint,
              controller: _notes,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => Navigator.of(context).pop(_notes.text.trim()),
            ),
            const SizedBox(height: 20),
            EthmarButton(
              label: s.save,
              onPressed: () => Navigator.of(context).pop(_notes.text.trim()),
            ),
            const SizedBox(height: 4),
            Center(
              child: EthmarLink(
                label: s.cancel,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

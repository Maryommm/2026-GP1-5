import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../models/farm_plant.dart';
import '../services/farm_store.dart';
import '../services/growth_photo_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart' show EthmarToastType, showEthmarToast;
import '../widgets/backgrounds.dart';
import '../widgets/camera_access.dart';
import '../widgets/entrance.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_header.dart';
import '../widgets/page_routes.dart';
import '../widgets/plant_picture.dart';
import 'edit_plant_screen.dart';

/// One plant, from the sketch: its picture, days since planting and
/// watering, the growth timeline (pictures with notes and dates), and the
/// care schedule with an Edit button.
///
/// [plantId] is the plant's Firestore document id.
class PlantDetailsScreen extends StatefulWidget {
  const PlantDetailsScreen({super.key, required this.plantId});
  final String plantId;

  @override
  State<PlantDetailsScreen> createState() => _PlantDetailsScreenState();
}

class _PlantDetailsScreenState extends State<PlantDetailsScreen> {
  bool _deleting = false;
  bool _closing = false;

  /// True while a growth picture is being uploaded and saved.
  bool _uploading = false;

  final _picker = ImagePicker();

  /// The growth timeline, newest first, live from Firestore.
  late final Stream<List<GrowthEntry>> _growth = FarmStore.watchGrowth(
    widget.plantId,
  );

  String get plantId => widget.plantId;

  /// Asks first, then deletes the plant and its growth entries.
  Future<void> _requestDelete(FarmPlant plant) async {
    if (_deleting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => _DeletePlantDialog(plantName: plant.name),
    );
    if (confirmed != true || !mounted || _deleting) return;

    setState(() => _deleting = true);
    try {
      await FarmStore.deletePlant(plantId);
      _closeOnce();
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showEthmarToast(
        context,
        S.of(context).plantDeleteFailed,
        type: EthmarToastType.error,
      );
    }
  }

  /// Closes this screen once the plant is gone. Firestore takes a deleted
  /// plant off the farm straight away, before the server confirms (offline,
  /// that can take a long time), so the screen doesn't wait for the delete.
  /// It may not be the top screen, e.g. when the plant was deleted on
  /// another device while Edit was open.
  void _closeOnce() {
    if (_closing || !mounted) return;
    _closing = true;
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    if (route == null || route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  /// "Upload a picture": camera or gallery, then optional notes, then the
  /// picture is uploaded and added to the timeline. A picture is required;
  /// the date is set when it's saved.
  Future<void> _addPicture(BuildContext context) async {
    if (_uploading) return;
    final s = S.of(context);
    final source = await showModalBottomSheet<ImageSource>(
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
              _SourceTile(
                icon: Icons.photo_camera_rounded,
                label: s.takePhoto,
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                label: s.chooseFromGallery,
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final image = await _pick(context, source);
    if (image == null || !context.mounted) return;
    final Uint8List preview;
    try {
      preview = await image.readAsBytes();
    } catch (_) {
      if (context.mounted) _error(context, s.errImageRead);
      return;
    }
    if (!context.mounted) return;

    final notes = await showDialog<String>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (_) => _NotesDialog(preview: preview),
    );
    if (notes == null || !context.mounted) return;

    setState(() => _uploading = true);
    try {
      await FarmStore.addGrowth(
        plantId,
        image,
        notes: notes.isEmpty ? null : notes,
      );
      if (context.mounted) showEthmarToast(context, s.pictureAdded);
    } on GrowthPhotoException catch (e) {
      debugPrint('Growth picture not added: $e');
      if (context.mounted) {
        _error(context, switch (e.error) {
          GrowthPhotoError.network => s.errNetwork,
          GrowthPhotoError.rateLimited => s.errProfilePhotoRateLimit,
          GrowthPhotoError.unreadableImage ||
          GrowthPhotoError.unsupportedImage => s.errImageRead,
          _ => s.errGrowthUpload,
        });
      }
    } catch (e) {
      debugPrint('Growth entry not saved: $e');
      if (context.mounted) _error(context, s.errGrowthUpload);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Opens the camera or gallery. Null when cancelled or not allowed.
  /// The photo comes back shrunk (see [GrowthPhotoService.pickWidth]).
  Future<XFile?> _pick(BuildContext context, ImageSource source) async {
    final s = S.of(context);
    if (source == ImageSource.camera && !await ensureCameraAccess(context)) {
      return null;
    }
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: GrowthPhotoService.pickWidth,
        maxHeight: GrowthPhotoService.pickWidth,
        imageQuality: GrowthPhotoService.pickQuality,
        requestFullMetadata: false,
      );
    } on PlatformException catch (e) {
      if (!context.mounted) return null;
      if (e.code == 'camera_access_denied') {
        await ensureCameraAccess(context);
      } else {
        _error(context, switch (e.code) {
          'no_available_camera' => s.errCameraOpen,
          'no_valid_image_uri' => s.errImageRead,
          _ =>
            source == ImageSource.camera ? s.errPhotoCapture : s.errPhotoSelect,
        });
      }
      return null;
    }
  }

  void _error(BuildContext context, String message) =>
      showEthmarToast(context, message, type: EthmarToastType.error);

  Future<void> _edit(BuildContext context) async {
    final saved = await Navigator.of(context)
        .push<bool>(riseRoute(EditPlantScreen(plantId: plantId)));
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
            final plant = FarmStore.plantById(plantId);
            // It was deleted (here or on another device): close.
            if (plant == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _closeOnce());
              return const SizedBox.shrink();
            }
            final crop = plant.crop;
            final irrigation = plant.irrigation;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EthmarPageHeader(
                  title: plant.name,
                  accent: crop.name.of(context),
                  trailing: _DeleteButton(
                    deleting: _deleting,
                    onPressed: () => _requestDelete(plant),
                  ),
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
                          child: PlantPicture(crop.image, cacheWidth: 400),
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
                        child: StreamBuilder<List<GrowthEntry>>(
                          stream: _growth,
                          builder: (context, snapshot) => _GrowthTimeline(
                            entries: snapshot.data ?? const [],
                            loading: !snapshot.hasData && !snapshot.hasError,
                            uploading: _uploading,
                            plantedAt: plant.plantedAt,
                            onAdd: () => _addPicture(context),
                          ),
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

/// Round delete button for the header; shows a spinner while deleting.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.deleting, required this.onPressed});

  final bool deleting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: IconButton(
        key: const ValueKey('delete-plant'),
        tooltip: S.of(context).deletePlant,
        onPressed: deleting ? null : onPressed,
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        icon: deleting
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.error,
                ),
              )
            : const Icon(Icons.delete_outline_rounded, color: AppColors.error),
      ),
    );
  }
}

/// Asks before deleting; the plant's growth entries go with it.
class _DeletePlantDialog extends StatelessWidget {
  const _DeletePlantDialog({required this.plantName});

  final String plantName;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.delete_outline_rounded,
              size: 42,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              s.deletePlantTitle,
              textAlign: TextAlign.center,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              s.deletePlantMessage(plantName),
              textAlign: TextAlign.center,
              style: AppText.body(context),
            ),
            const SizedBox(height: 22),
            EthmarButton(
              key: const ValueKey('confirm-delete-plant'),
              label: s.deletePlant,
              color: AppColors.error,
              textColor: AppColors.surface,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 4),
            Center(
              child: EthmarLink(
                label: s.cancel,
                onTap: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

  /// Null greys it out (e.g. while a picture uploads).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onPressed == null
          ? AppColors.forest.withValues(alpha: 0.45)
          : AppColors.forest,
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

/// The growth timeline: newest at the top, a dot and line down the side,
/// then the "Upload a picture" button. Each entry shows its picture, which
/// day of the plant's life it's from, its notes and its date.
class _GrowthTimeline extends StatelessWidget {
  const _GrowthTimeline({
    required this.entries,
    required this.loading,
    required this.uploading,
    required this.plantedAt,
    required this.onAdd,
  });
  final List<GrowthEntry> entries;

  /// True until the entries first arrive.
  final bool loading;

  /// True while a new picture is being uploaded: it shows on top.
  final bool uploading;
  final DateTime plantedAt;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final loc = MaterialLocalizations.of(context);
    final rows = entries.length + (uploading ? 1 : 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.forest,
                ),
              ),
            ),
          )
        else if (rows == 0)
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
          for (var i = 0; i < rows; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TimelineRail(first: i == 0, last: i == rows - 1),
                  const SizedBox(width: 10),
                  if (uploading && i == 0) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: _PhotoFrame(busy: true),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 14),
                        child: Text(
                          s.uploadingPicture,
                          style: AppText.small(context),
                        ),
                      ),
                    ),
                  ] else
                    ..._entryRow(
                      context,
                      s,
                      loc,
                      entries[uploading ? i - 1 : i],
                    ),
                ],
              ),
            ),
        const SizedBox(height: 14),
        Center(
          child: _SmallButton(
            label: s.uploadPicture,
            icon: Icons.add_a_photo_rounded,
            onPressed: uploading ? null : onAdd,
          ),
        ),
      ],
    );
  }

  List<Widget> _entryRow(
    BuildContext context,
    S s,
    MaterialLocalizations loc,
    GrowthEntry entry,
  ) {
    final notes = entry.notes;
    final photo = entry.photo;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _PhotoFrame(
          photo: photo,
          onTap: photo == null ? null : () => _showPhoto(context, entry),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.growthDay(entry.dayOf(plantedAt)),
                style: AppText.label(context)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              if (notes != null) ...[
                const SizedBox(height: 2),
                Text(notes, style: AppText.label(context)),
              ],
              const SizedBox(height: 4),
              Text(
                loc.formatMediumDate(entry.date),
                style: AppText.small(context),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// The picture full screen, to zoom in, with its notes underneath.
  void _showPhoto(BuildContext context, GrowthEntry entry) {
    final photo = entry.photo!;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _PhotoViewer(
        photo: photo,
        caption: [
          S.of(context).growthDay(entry.dayOf(plantedAt)),
          ?entry.notes,
        ].join(' · '),
      ),
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

/// A picture on the timeline: the sketch's dotted square, with the photo
/// inside once there is one ([photo] from Cloudinary, or [preview] bytes
/// just picked). [busy] shows a spinner while it uploads.
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({
    this.photo,
    this.preview,
    this.busy = false,
    this.onTap,
    this.size = 76,
  });
  final GrowthPhoto? photo;
  final Uint8List? preview;
  final bool busy;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cache = (size * MediaQuery.devicePixelRatioOf(context)).round();
    const placeholder = Icon(
      Icons.image_outlined,
      color: AppColors.forest,
      size: 28,
    );
    final p = photo;
    final bytes = preview;
    final Widget inside;
    if (busy) {
      inside = const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.forest,
          ),
        ),
      );
    } else if (bytes != null) {
      inside = Image.memory(bytes, fit: BoxFit.cover, cacheWidth: cache);
    } else if (p != null) {
      inside = Image.network(
        p.url,
        fit: BoxFit.cover,
        cacheWidth: cache,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else {
      inside = placeholder;
    }

    final framed = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.forestTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: inside,
    );
    final tap = onTap;
    return CustomPaint(
      // The dotted outline only while there's no picture inside.
      foregroundPainter: p == null && bytes == null
          ? const _DottedFrame()
          : null,
      child: tap == null
          ? framed
          : Semantics(
              button: true,
              child: GestureDetector(onTap: tap, child: framed),
            ),
    );
  }
}

/// A growth picture full screen: pinch to zoom, X (or back) to close.
class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo, required this.caption});
  final GrowthPhoto photo;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    photo.url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) =>
                        progress == null
                        ? child
                        : const CircularProgressIndicator(
                            color: AppColors.onForest,
                          ),
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.onForest,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 8,
              end: 8,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: AppText.label(context, color: Colors.white),
              ),
            ),
          ],
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

/// After choosing a picture: the picture, and optional notes for this
/// growth stage. Pops with the notes ('' when left empty), or null on cancel.
class _NotesDialog extends StatefulWidget {
  const _NotesDialog({required this.preview});

  /// The picture just picked.
  final Uint8List preview;

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  /// The rules accept notes up to this long.
  static const _maxNotes = 500;

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
            Center(child: _PhotoFrame(preview: widget.preview, size: 160)),
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
              inputFormatters: [LengthLimitingTextInputFormatter(_maxNotes)],
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

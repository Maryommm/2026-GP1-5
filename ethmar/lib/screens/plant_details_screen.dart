import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../models/care_task.dart';
import '../models/daily_task.dart' show TaskType;
import '../models/farm_plant.dart';
import '../services/farm_store.dart';
import '../services/network_errors.dart';
import '../services/journey_photo_service.dart';
import '../services/recent_task_logs.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart' show EthmarToastType, showEthmarToast;
import '../widgets/backgrounds.dart';
import '../widgets/camera_access.dart';
import '../widgets/entrance.dart';
import '../widgets/care_icon.dart';
import '../widgets/category_chip.dart' show categoryLabel;
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/centered_header.dart';
import '../widgets/page_routes.dart';
import '../widgets/plant_picture.dart';
import 'edit_plant_screen.dart';

/// One plant's page: its picture, days since planting and watering, the
/// journey timeline (photos with notes and dates), and the care schedule
/// with an Edit button.
///
/// [plantId] is the plant's Firestore document id.
class PlantDetailsScreen extends StatefulWidget {
  const PlantDetailsScreen({super.key, required this.plantId, this.addedPlant});
  final String plantId;

  /// The plant just saved by Add Plant. It is shown until the farm's live
  /// list includes it, which can take a moment, so the page opens at once.
  final FarmPlant? addedPlant;

  @override
  State<PlantDetailsScreen> createState() => _PlantDetailsScreenState();
}

class _PlantDetailsScreenState extends State<PlantDetailsScreen> {
  bool _deleting = false;
  bool _closing = false;

  /// True once the plant has been found in [FarmStore.plants]. Until then a
  /// just-added plant is shown from [PlantDetailsScreen.addedPlant]; after
  /// that, the plant missing from the list means it was deleted.
  bool _seen = false;

  /// True while a journey photo is being uploaded and saved.
  bool _uploading = false;

  final _picker = ImagePicker();

  /// The journey timeline, newest first, live from Firestore.
  late final Stream<List<JourneyEntry>> _journey = FarmStore.watchJourney(
    widget.plantId,
  );

  String get plantId => widget.plantId;

  /// Asks first, then deletes the plant and its journey entries.
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
    } catch (e) {
      // Not deleted (or not confirmed): the plant stays, and deleting it again
      // is safe.
      if (!mounted) return;
      setState(() => _deleting = false);
      final s = S.of(context);
      showEthmarToast(
        context,
        isNetworkError(e) ? s.plantDeleteFailed : s.plantDeleteFailedGeneric,
        type: EthmarToastType.error,
      );
    }
  }

  /// Closes this screen once the plant is gone: when its delete is confirmed,
  /// or when it disappears from the farm (e.g. deleted on another device).
  /// It might not be the top screen, e.g. if the plant was deleted on another
  /// device while Edit was open.
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
  /// photo is uploaded and added to the timeline. A photo is required, and
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
      await FarmStore.addJourneyEntry(
        plantId,
        image,
        notes: notes.isEmpty ? null : notes,
      );
      if (context.mounted) showEthmarToast(context, s.pictureAdded);
    } on JourneyPhotoException catch (e) {
      debugPrint('Journey picture not added: $e');
      if (context.mounted) {
        _error(context, switch (e.error) {
          JourneyPhotoError.network => s.errNetwork,
          JourneyPhotoError.rateLimited => s.errProfilePhotoRateLimit,
          JourneyPhotoError.unreadableImage ||
          JourneyPhotoError.unsupportedImage => s.errImageRead,
          _ => s.errJourneyUpload,
        });
      }
    } catch (e) {
      debugPrint('Journey entry not saved: $e');
      if (context.mounted) _error(context, s.errJourneyUpload);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Opens the camera or gallery. Returns null if cancelled or not allowed.
  /// The photo comes back smaller (see [JourneyPhotoService.pickWidth]).
  Future<XFile?> _pick(BuildContext context, ImageSource source) async {
    final s = S.of(context);
    if (source == ImageSource.camera && !await ensureCameraAccess(context)) {
      return null;
    }
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: JourneyPhotoService.pickWidth,
        maxHeight: JourneyPhotoService.pickWidth,
        imageQuality: JourneyPhotoService.pickQuality,
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
            final loaded = FarmStore.plantById(plantId);
            if (loaded != null) _seen = true;
            final plant = loaded ?? (_seen ? null : widget.addedPlant);
            if (plant == null) {
              // It was deleted (here or on another device), so close the screen.
              WidgetsBinding.instance.addPostFrameCallback((_) => _closeOnce());
              return const SizedBox.shrink();
            }
            final crop = plant.crop;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Only the user's name for the plant. What it is shows in the crop card
                // below.
                EthmarCenteredHeader(title: plant.name),
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
                        // Delete is in the picture card's top corner on the end side (top left in
                        // Arabic, top right in English), away from the centred picture.
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              key: const Key('plantPictureFrame'),
                              height: 170,
                              padding: const EdgeInsets.all(14),
                              decoration: plantPictureFrame(28),
                              child: Center(
                                child: PlantPicture(
                                  crop.image,
                                  cacheWidth: 400,
                                ),
                              ),
                            ),
                            _onCorner(
                              radius: 28,
                              child: _DeleteButton(
                                deleting: _deleting,
                                onPressed: () => _requestDelete(plant),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Both cards are as tall as the taller one.
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _StatCard(
                                label: s.daysSincePlanting,
                                value: s.plantAge(plant.daysSincePlanting),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // What the plant is, from the crop catalog (the user's own name is the
                            // page title): the crop's name and the plant's category.
                            Expanded(
                              child: _StatCard(
                                key: const Key('plantCropCard'),
                                label: s.plantCropLabel,
                                // One line, e.g. "Strawberry - Fruits".
                                value: '${crop.name.of(context)} - '
                                    '${categoryLabel(plant.category, context)}',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Panel(
                        title: s.journeyTitle,
                        child: StreamBuilder<List<JourneyEntry>>(
                          stream: _journey,
                          builder: (context, snapshot) => _JourneyTimeline(
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
                        // A pencil button on the card's end corner (top left in Arabic, top right
                        // in English).
                        corner: _CornerButton(
                          key: const Key('edit-schedule'),
                          tooltip: s.edit,
                          onPressed: () => _edit(context),
                          icon: const Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: AppColors.forest,
                          ),
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
// Smaller widgets used on this screen
// ---------------------------------------------------------------------------

/// The delete button on the picture card's corner (see [_onCorner]). Shows
/// a spinner while deleting.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.deleting, required this.onPressed});

  final bool deleting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _CornerButton(
      key: const ValueKey('delete-plant'),
      tooltip: S.of(context).deletePlant,
      onPressed: deleting ? null : onPressed,
      icon: deleting
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.error,
              ),
            )
          : const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: AppColors.error,
            ),
    );
  }
}

/// Asks before deleting. The plant's journey entries are deleted too.
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

/// A small white box with a label on top and the value below.
class _StatCard extends StatelessWidget {
  const _StatCard({super.key, required this.label, required this.value});
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
                  .copyWith(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// A white rounded card with a title (and an optional button next to it).
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.corner});
  final String title;
  final Widget child;

  /// A button on the card's top corner on the end side (see [_onCorner]).
  final Widget? corner;

  static const _radius = 24.0;

  @override
  Widget build(BuildContext context) {
    final c = corner;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                // Leave space for the corner button.
                padding: EdgeInsetsDirectional.only(end: c == null ? 0 : 20),
                child: Text(
                  title,
                  style: AppText.label(context)
                      .copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
        if (c != null) _onCorner(radius: _radius, child: c),
      ],
    );
  }
}

/// Places a [_CornerButton] on the top corner (end side) of a card with
/// [radius] corners. It sits on the middle of the corner's curve, so the
/// circle is half inside and half outside the border. Use it in a [Stack]
/// with `clipBehavior: Clip.none`.
Widget _onCorner({required double radius, required Widget child}) {
  // The middle of the curve, measured in from the box's corner.
  final inset = radius * (1 - math.sqrt1_2);
  const half = _CornerButton.tapTarget / 2;
  return PositionedDirectional(top: inset - half, end: inset - half, child: child);
}

/// A small white circle with a thin outline and an icon, for a card's
/// corner (see [_onCorner]). It is 36 wide, but the tap area is 48.
class _CornerButton extends StatelessWidget {
  const _CornerButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  static const size = 36.0;
  static const tapTarget = 48.0;

  final String tooltip;

  /// Null while it can't be used (e.g. while deleting).
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    // Center lets the circle stay 36 while the tap area fills the 48 box.
    return SizedBox.square(
      dimension: tapTarget,
      child: Center(
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            fixedSize: const Size.square(size),
            minimumSize: const Size.square(size),
            tapTargetSize: MaterialTapTargetSize.padded,
            backgroundColor: AppColors.surface,
            disabledBackgroundColor: AppColors.surface,
            side: const BorderSide(color: AppColors.border),
            shadowColor: AppColors.forest.withValues(alpha: 0.2),
            elevation: 1,
          ),
          icon: icon,
        ),
      ),
    );
  }
}

/// A small green pill button, like "Upload a picture". The pill is 36 high,
/// but the tap area is 48 high so it's easy to hit.
class _SmallButton extends StatelessWidget {
  const _SmallButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  final String label;
  final IconData icon;

  /// Null makes it grey and disabled (e.g. while a photo uploads).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          widthFactor: 1,
          child: Material(
            color: onPressed == null
                ? AppColors.forest.withValues(alpha: 0.45)
                : AppColors.forest,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              splashColor: const Color(0x22FFFFFF),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 14, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 15, color: AppColors.onForest),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style:
                              AppText.button(context).copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The journey timeline: newest at the top, with a dot and line down the
/// side, then the "Upload a picture" button. Each entry shows its photo,
/// which day of the plant's life it's from, its notes and its date.
class _JourneyTimeline extends StatelessWidget {
  const _JourneyTimeline({
    required this.entries,
    required this.loading,
    required this.uploading,
    required this.plantedAt,
    required this.onAdd,
  });
  final List<JourneyEntry> entries;

  /// True until the entries load for the first time.
  final bool loading;

  /// True while a new photo is uploading (it shows at the top).
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
                child: Text(s.journeyEmpty, style: AppText.small(context)),
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
            key: const Key('upload-picture'),
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
    JourneyEntry entry,
  ) {
    final notes = entry.notes;
    final photo = entry.photo;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: _PhotoFrame(
          photo: photo,
          onTap: () => _showPhoto(context, entry),
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
                s.journeyDay(entry.dayOf(plantedAt)),
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

  /// Shows the photo full screen (with zoom) and its notes underneath.
  void _showPhoto(BuildContext context, JourneyEntry entry) {
    final photo = entry.photo;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => _PhotoViewer(
        photo: photo,
        caption: [
          S.of(context).journeyDay(entry.dayOf(plantedAt)),
          ?entry.notes,
        ].join(' · '),
      ),
    );
  }
}

/// The dot and line next to each timeline entry.
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

/// A photo on the timeline: a dotted square, with the photo inside once
/// there is one ([photo] from Cloudinary, or [preview] bytes just picked).
/// [busy] shows a spinner while it uploads.
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({
    this.photo,
    this.preview,
    this.busy = false,
    this.onTap,
    this.size = 76,
  });
  final JourneyPhoto? photo;
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
      // The dotted outline is only shown while there's no photo inside.
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

/// A journey photo full screen: pinch to zoom, X (or back) to close.
class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo, required this.caption});
  final JourneyPhoto photo;
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

/// The care schedule rows: the task on one side, how often and when it's
/// next due on the other. "Next" is the same task Daily Tasks shows (see
/// careState): today's task if it isn't done, a missed one while it can
/// still be done, otherwise the next one.
class _ScheduleRows extends StatefulWidget {
  const _ScheduleRows({required this.plant});
  final FarmPlant plant;

  @override
  State<_ScheduleRows> createState() => _ScheduleRowsState();
}

class _ScheduleRowsState extends State<_ScheduleRows> {
  /// Today's and the missed days' task logs (same as Daily Tasks).
  final _logs = RecentTaskLogs();
  late final AppLifecycleListener _lifecycle;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _logs.addListener(_refresh);
    _lifecycle = AppLifecycleListener(onResume: _onClock);
    // Update every minute so a new day starts at midnight while the page is
    // open.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => _onClock());
  }

  @override
  void dispose() {
    _logs.dispose();
    _lifecycle.dispose();
    _clock?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onClock() {
    _logs.checkDay();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final plant = widget.plant;
    final now = DateTime.now();
    CareState? stateOf(TaskType type) =>
        careState(plant, type, now, logs: _logs.logs);
    return Column(
      children: [
        _ScheduleRow(
          type: TaskType.watering,
          task: s.summaryIrrigation,
          schedule: plant.irrigation,
          state: stateOf(TaskType.watering),
        ),
        const Divider(height: 24, color: AppColors.border),
        _ScheduleRow(
          type: TaskType.fertilizing,
          task: s.summaryFertilization,
          schedule: plant.fertilization,
          state: stateOf(TaskType.fertilizing),
        ),
      ],
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.type,
    required this.task,
    required this.schedule,
    required this.state,
  });
  final TaskType type;
  final String task;
  final CareSchedule? schedule;
  final CareState? state;

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
    final st = state;
    // Start side: the icon, the task and how often (or "Not set"). End side:
    // when it's next due, or since when it's missed.
    return MergeSemantics(
      child: Row(
        key: Key('schedule_${type.name}'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.seaTint,
              shape: BoxShape.circle,
            ),
            // The fertilizer bag fills more of its square than the drop, so it's drawn
            // a little smaller to look the same size.
            child: CareTypeIcon(
              type,
              size: type == TaskType.fertilizing ? 16 : 18,
              color: AppColors.seaDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task,
                  style: AppText.label(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  c == null ? s.scheduleNotSet : c.repeat.label(s),
                  style: AppText.small(context),
                ),
              ],
            ),
          ),
          if (st != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                switch (st.missed) {
                  final missed? =>
                    s.scheduleMissed(_when(context, st.at(missed))),
                  null => s.scheduleNext(_when(context, st.at(st.next))),
                },
                textAlign: TextAlign.end,
                style: AppText.small(
                  context,
                  color: st.missed != null
                      ? AppColors.error
                      : AppColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ],
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

/// After choosing a photo: shows the photo and optional notes for this
/// growth stage. Returns the notes ('' when empty), or null on cancel.
class _NotesDialog extends StatefulWidget {
  const _NotesDialog({required this.preview});

  /// The photo that was just picked.
  final Uint8List preview;

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  /// The Firestore rules allow notes up to this length.
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

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/farm_plant.dart';
import '../services/farm_store.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_header.dart' show EthmarToastType, showEthmarToast;
import '../widgets/backgrounds.dart';
import '../widgets/care_schedule_editor.dart';
import '../widgets/centered_header.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';

/// Edit a plant's name and care schedules, starting from what's saved.
class EditPlantScreen extends StatefulWidget {
  const EditPlantScreen({super.key, required this.plantId});
  final String plantId;

  @override
  State<EditPlantScreen> createState() => _EditPlantScreenState();
}

class _EditPlantScreenState extends State<EditPlantScreen> {
  late final FarmPlant _plant = FarmStore.plantById(widget.plantId)!;

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _plant.name);
  bool _saving = false;

  // Off schedules start from the same defaults as when adding a plant.
  late final _irrigation = ScheduleDraft.from(
    _plant.irrigation,
    Repeat.everyDay,
    const TimeOfDay(hour: 7, minute: 0),
  );
  late final _fertilization = ScheduleDraft.from(
    _plant.fertilization,
    Repeat.everyWeek,
    const TimeOfDay(hour: 8, minute: 0),
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await FarmStore.updatePlant(
        _plant.edited(
          name: _name.text.trim(),
          irrigation: _irrigation.result,
          fertilization: _fertilization.result,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showEthmarToast(
        context,
        S.of(context).farmSaveFailed,
        type: EthmarToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: LeafPrintBackground(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EthmarCenteredHeader(title: s.editPlantTitle),
              Text(
                _plant.crop.name.of(context),
                textAlign: TextAlign.center,
                style: AppText.small(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  children: [
                    EthmarTextField(
                      label: s.addPlantNameLabel,
                      hint: s.addPlantNameHint,
                      controller: _name,
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        final name = v?.trim() ?? '';
                        if (name.isEmpty) return s.errPlantNameRequired;
                        if (name.length > 30) return s.errPlantNameLong;
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    CareScheduleCard(
                      irrigation: _irrigation,
                      fertilization: _fertilization,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EthmarButton(
                        label: s.save,
                        onPressed: _save,
                        loading: _saving,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

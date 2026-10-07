import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/farm_plant.dart';
import '../services/farm_store.dart';
import '../widgets/backgrounds.dart';
import '../widgets/care_schedule_editor.dart';
import '../widgets/ethmar_buttons.dart';
import '../widgets/ethmar_text_field.dart';
import '../widgets/page_header.dart';

/// Edit a plant's name and care schedules, starting from what's saved.
/// Pops with true once saved.
///
/// [index] is the plant's number on the farm (see [FarmStore]).
class EditPlantScreen extends StatefulWidget {
  const EditPlantScreen({super.key, required this.index});
  final int index;

  @override
  State<EditPlantScreen> createState() => _EditPlantScreenState();
}

class _EditPlantScreenState extends State<EditPlantScreen> {
  late final FarmPlant _plant = FarmStore.plants.value[widget.index];

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: _plant.name);

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

  void _save() {
    if (!_form.currentState!.validate()) return;
    // TODO(backend): Save the changes (and reschedule the reminders).
    FarmStore.updatePlant(
      widget.index,
      _plant.edited(
        name: _name.text.trim(),
        irrigation: _irrigation.result,
        fertilization: _fertilization.result,
      ),
    );
    Navigator.of(context).pop(true);
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
              EthmarPageHeader(
                title: s.editPlantTitle,
                accent: _plant.crop.name.of(context),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      EthmarButton(label: s.save, onPressed: _save),
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

import 'package:regun/services/economy/armory_repository.dart';
import 'package:flutter/material.dart';
import 'package:regun/data/loadout.dart';
import 'package:regun/models/economy/career_progress.dart';
import 'package:regun/models/player_profile.dart';
import 'package:regun/services/local_preferences.dart';
import 'package:regun/utils/constants.dart';
import 'package:regun/widgets/click_button.dart';

/// Trying a weapon never changes its normal-run unlock or grants rewards.
class TrainingWeaponBrowser extends StatefulWidget {
  const TrainingWeaponBrowser({
    super.key,
    required this.selected,
    required this.builder,
    this.preferences,
    this.initialTryLocked = false,
    this.onGroupChanged,
  });
  final bool initialTryLocked;
  final ValueChanged<bool>? onGroupChanged;
  final WeaponType selected;
  final Widget Function(List<WeaponType> weapons, Widget? selectedDetails)
  builder;
  final LocalPreferences? preferences;
  @override
  State<TrainingWeaponBrowser> createState() => _TrainingWeaponBrowserState();
}

class _TrainingWeaponBrowserState extends State<TrainingWeaponBrowser> {
  bool _tryLocked = false, _saving = false;
  String? _issue;
  @override
  void initState() {
    super.initState();
    _tryLocked = widget.initialTryLocked;
  }

  LocalPreferences get source => widget.preferences ?? LocalPreferences.shared;

  Future<void> _pin(String id) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _issue = null;
    });
    final owner = source.profileOwner;
    final next = PlayerProfile.fromJson(source.profile.toJson())
      ..pinnedGoal = id;
    final saved = await source.saveProfile(next: next);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (source.profileOwner == owner) {
        _issue = saved
            ? 'Goal pinned.'
            : 'Could not save your goal. Try again.';
      }
    });
  }

  Widget _goalDetails(PlayerProfile profile, CareerGoal goal) {
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.selected.title} / TRAINING ONLY',
          key: const Key('training-locked-weapon'),
          style: const TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: 11,
            height: 1.5,
            color: Color(0xffE1BA78),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Unlock: ${goal.detail}',
          key: const Key('training-unlock-requirement'),
          style: const TextStyle(
            fontFamily: FontFam.orbitron,
            fontSize: 10,
            height: 1.5,
            color: Color(0xffE5DDD1),
          ),
        ),
      ],
    );
    final pin = ClickButton(
      key: const Key('training-pin-weapon-goal'),
      text: _saving
          ? 'Saving'
          : profile.pinnedGoal == goal.id
          ? 'Goal pinned'
          : 'Pin unlock goal',
      width: 172,
      height: 48,
      fontSize: 8,
      onTap: _saving || profile.pinnedGoal == goal.id
          ? null
          : () => _pin(goal.id),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 236, child: label),
          pin,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: source,
    builder: (context, _) {
      final profile = source.profile;
      final weapons = WeaponType.values
          .where((w) => profile.weaponUnlocked(w) != _tryLocked)
          .toList();
      final goalId = widget.selected == WeaponType.carbine
          ? 'training'
          : widget.selected.name;
      final goal = CareerProgress(
        profile,
        armory: ArmoryRepository.shared.catalog,
      ).goals.where((g) => g.id == goalId).firstOrNull;
      final locked = !profile.weaponUnlocked(widget.selected);
      final Widget? details = locked && goal != null
          ? _goalDetails(profile, goal)
          : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in [false, true])
                Semantics(
                  selected: _tryLocked == option,
                  child: ClickButton(
                    key: ValueKey(
                      option ? 'training-try-locked' : 'training-your-weapons',
                    ),
                    text: option ? 'Try locked weapons' : 'Your weapons',
                    width: option ? 196 : 156,
                    height: 48,
                    fontSize: 8,
                    buttonColor: _tryLocked == option
                        ? const Color(0xffE1BA78)
                        : const Color(0xff746878),
                    onTap: () {
                      setState(() {
                        _tryLocked = option;
                        _issue = null;
                      });
                      widget.onGroupChanged?.call(option);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_tryLocked)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Try it here. Earn it for normal runs. No Scrap or challenge rewards.',
                style: TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: 10,
                  height: 1.5,
                  color: Color(0xffB2A8B4),
                ),
              ),
            ),
          if (details != null && !weapons.contains(widget.selected)) details,
          if (_issue != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _issue!,
                style: const TextStyle(
                  fontFamily: FontFam.orbitron,
                  fontSize: 10,
                  height: 1.5,
                  color: Color(0xffE1BA78),
                ),
              ),
            ),
          if (weapons.isEmpty)
            const Text(
              'All weapons earned. Find them in Your weapons.',
              style: TextStyle(
                fontFamily: FontFam.orbitron,
                fontSize: 11,
                height: 1.5,
                color: Color(0xffB2A8B4),
              ),
            )
          else
            widget.builder(weapons, details),
        ],
      );
    },
  );
}

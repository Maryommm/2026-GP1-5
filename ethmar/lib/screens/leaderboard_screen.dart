import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/farm_store.dart';
import '../services/user_service.dart' show currentUsername;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';
import '../widgets/page_header.dart';

/// Leaderboard (from the sketch): where the user ranks by number of plants,
/// a podium for the top 3, then places 4 to 10. If the user is further
/// down, their own row follows the list.
///
/// The rank and podium sit on a dark green "stage" so the top 3 stand out;
/// the list below stays light and calm.
///
/// UI only for now: the other players are made up; the user's count comes
/// from their farm.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final name = currentUsername.value.isEmpty
        ? s.homeFriend
        : currentUsername.value;
    final players = _ranked(name, FarmStore.plants.value.length);
    final you = players.indexWhere((p) => p.isYou);
    final topTen = players.take(10).toList();
    return Scaffold(
      body: LeafPrintBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EthmarPageHeader(
              title: s.leaderboardTitle,
              accent: s.leaderboardAccent,
              trailing: const EthmarCharacter(
                name: 'ethmar_buddy_jumping',
                height: 64,
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
                    child: _Stage(
                      rank: you + 1,
                      plants: players[you].plants,
                      // Plants needed to pass whoever is 10th now.
                      tenthPlants:
                          players[math.min(9, players.length - 1)].plants,
                      top3: players.take(3).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 3; i < topTen.length; i++)
                    Entrance(
                      delay: Duration(milliseconds: 450 + 40 * (i - 3)),
                      offset: 16,
                      child: _RankRow(rank: i + 1, player: players[i]),
                    ),
                  // Further down: the user's own row, after a gap.
                  if (you >= 10) ...[
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: AppColors.textHint,
                      ),
                    ),
                    Entrance(
                      delay: const Duration(milliseconds: 750),
                      offset: 16,
                      child: _RankRow(rank: you + 1, player: players[you]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Players
// ---------------------------------------------------------------------------

class _Player {
  const _Player(this.name, this.plants, {this.isYou = false});
  final String name;
  final int plants;
  final bool isYou;
}

// TODO(backend): Load the real leaderboard (usernames and plant counts) and
//   the user's rank from the database.
const _otherPlayers = [
  _Player('sara.grows', 58),
  _Player('abdullah_farm', 47),
  _Player('lama.green', 41),
  _Player('fahad_92', 36),
  _Player('reem.plants', 33),
  _Player('omar_seeds', 29),
  _Player('hind.garden', 26),
  _Player('khalid.k', 24),
  _Player('maha_bloom', 21),
  _Player('yousef.sprout', 19),
  _Player('nouf_leaf', 15),
  _Player('turki_tree', 12),
  _Player('dana.dates', 9),
  _Player('salem_soil', 6),
];

/// Everyone, most plants first. On a tie the user goes after the others.
List<_Player> _ranked(String name, int plants) {
  final all = [..._otherPlayers, _Player(name, plants, isYou: true)];
  all.sort((a, b) {
    final byPlants = b.plants.compareTo(a.plants);
    if (byPlants != 0) return byPlants;
    return (a.isYou ? 1 : 0).compareTo(b.isYou ? 1 : 0);
  });
  return all;
}

// ---------------------------------------------------------------------------
// Colours
// ---------------------------------------------------------------------------

/// The stage: deep forest, a touch lighter at the top.
const _stageTop = Color(0xFF173A26);
const _stageBottom = Color(0xFF0F2418);

/// One accent per podium place: warm gold, fresh mint, soft peach.
const _placeAccent = {
  1: Color(0xFFFFC93C),
  2: Color(0xFF7FE0CF),
  3: Color(0xFFFFA98F),
};

/// Pastel (background, letter) pairs for the list's avatars.
const _pastels = [
  (Color(0xFFDDF5EA), Color(0xFF1E7A55)), // mint
  (Color(0xFFFFE6DC), Color(0xFFB4492A)), // peach
  (Color(0xFFFFF1C9), Color(0xFF7A5600)), // butter
  (Color(0xFFDDEEFF), Color(0xFF1F5C9E)), // sky
  (Color(0xFFEAE4FF), Color(0xFF5A43AD)), // lilac
];

/// The same pastel for the same name, every time.
(Color, Color) _pastelFor(String name) {
  var sum = 0;
  for (final c in name.codeUnits) {
    sum += c;
  }
  return _pastels[sum % _pastels.length];
}

// ---------------------------------------------------------------------------
// The stage: your rank, progress to the top 10, and the podium
// ---------------------------------------------------------------------------

class _Stage extends StatelessWidget {
  const _Stage({
    required this.rank,
    required this.plants,
    required this.tenthPlants,
    required this.top3,
  });
  final int rank;
  final int plants;
  final int tenthPlants;
  final List<_Player> top3;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final inTopTen = rank <= 10;
    final toGo = tenthPlants + 1 - plants;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_stageTop, _stageBottom],
          ),
        ),
        child: Stack(
          children: [
            // Soft gold glow behind 1st place.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, 0.3),
                      radius: 0.7,
                      colors: [
                        _placeAccent[1]!.withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _placeAccent[1],
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '#$rank',
                          textDirection: TextDirection.ltr,
                          style: AppText.title(
                            context,
                            color: _stageBottom,
                          ).copyWith(fontSize: 21),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          s.rankMessage(rank, plants),
                          style: AppText.label(
                            context,
                            color: Colors.white,
                          ).copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!inTopTen) ...[
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _TopTenProgress(
                      value: plants / (tenthPlants + 1),
                      caption: s.rankToTopTen(toGo),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _Podium(top3: top3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A gold bar filling up towards the top 10, with how many plants to go.
class _TopTenProgress extends StatelessWidget {
  const _TopTenProgress({required this.value, required this.caption});
  final double value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: _placeAccent[1],
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          style: AppText.small(
            context,
            color: Colors.white.withValues(alpha: 0.75),
          ).copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

/// Top 3 on frosted steps: 2nd, 1st (tallest, with a trophy), 3rd. Each
/// rises in one after another.
class _Podium extends StatelessWidget {
  const _Podium({required this.top3});
  final List<_Player> top3;

  @override
  Widget build(BuildContext context) {
    const heights = {1: 92.0, 2: 66.0, 3: 50.0};
    const delays = {3: 150, 2: 300, 1: 450};
    Widget place(int rank) => Expanded(
      child: _PodiumPlace(
        rank: rank,
        player: top3[rank - 1],
        stepHeight: heights[rank]!,
        delay: Duration(milliseconds: delays[rank]!),
      ),
    );
    return SizedBox(
      // Room for the tallest place, including the steps' little bounce.
      height: 262,
      child: Row(
        // Same layout in both languages, like a real podium.
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [place(2), place(1), place(3)],
      ),
    );
  }
}

class _PodiumPlace extends StatefulWidget {
  const _PodiumPlace({
    required this.rank,
    required this.player,
    required this.stepHeight,
    required this.delay,
  });
  final int rank;
  final _Player player;
  final double stepHeight;
  final Duration delay;

  @override
  State<_PodiumPlace> createState() => _PodiumPlaceState();
}

class _PodiumPlaceState extends State<_PodiumPlace>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final _rise = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status != AnimationStatus.dismissed) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      return;
    }
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final accent = _placeAccent[widget.rank]!;
    final first = widget.rank == 1;
    final p = widget.player;
    final size = first ? 62.0 : 52.0;
    return MergeSemantics(
      child: Semantics(
        label: s.rankLabel(widget.rank),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // The player pops up with their step.
              FadeTransition(
                opacity: _c,
                child: ScaleTransition(
                  scale: _rise,
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    children: [
                      if (first)
                        Icon(
                          Icons.emoji_events_rounded,
                          size: 26,
                          color: accent,
                        ),
                      const SizedBox(height: 2),
                      Container(
                        width: size,
                        height: size,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.isYou ? Colors.white : _stageTop,
                          shape: BoxShape.circle,
                          border: Border.all(color: accent, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.45),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Text(
                          p.name.characters.first.toUpperCase(),
                          style: AppText.title(
                            context,
                            color: p.isYou ? _stageBottom : Colors.white,
                          ).copyWith(fontSize: size * 0.42),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.isYou ? s.you : p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label(
                          context,
                          color: Colors.white,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.plantsCount(p.plants),
                        style: AppText.small(
                          context,
                          color: accent,
                        ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              // The step grows up from the bottom of the stage.
              AnimatedBuilder(
                animation: _rise,
                builder: (context, child) => SizedBox(
                  height: widget.stepHeight * _rise.value.clamp(0.0, 1.08),
                  child: child,
                ),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: first ? 0.2 : 0.13),
                        Colors.white.withValues(alpha: 0.03),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: accent.withValues(alpha: 0.9),
                        width: 3,
                      ),
                    ),
                  ),
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${widget.rank}',
                    style: AppText.title(
                      context,
                      color: accent,
                    ).copyWith(fontSize: first ? 32 : 26),
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

// ---------------------------------------------------------------------------
// The list: places 4 to 10 (and the user, if further down)
// ---------------------------------------------------------------------------

/// One player on a white row. The user's own row is dark green, so it's
/// easy to spot.
class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.player});
  final int rank;
  final _Player player;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final you = player.isYou;
    final fg = you ? Colors.white : AppColors.forest;
    final (avatarBg, avatarFg) = you
        ? (_placeAccent[1]!, _stageBottom)
        : _pastelFor(player.name);
    return MergeSemantics(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: you ? _stageTop : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.forest.withValues(alpha: you ? 0.25 : 0.06),
              blurRadius: you ? 14 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: AppText.label(
                  context,
                  color: you
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppColors.textSecondary,
                ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: avatarBg,
                shape: BoxShape.circle,
              ),
              child: Text(
                player.name.characters.first.toUpperCase(),
                style: AppText.label(
                  context,
                  color: avatarFg,
                ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                you ? '${player.name} (${s.you})' : player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label(
                  context,
                  color: fg,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.eco_rounded,
              size: 16,
              color: you ? _placeAccent[1] : AppColors.sea,
            ),
            const SizedBox(width: 4),
            Text(
              '${player.plants}',
              style: AppText.label(
                context,
                color: fg,
              ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

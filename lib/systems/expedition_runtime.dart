part of '../game.dart';

extension ExpeditionRuntime on RegunGame {
  void _configureExpeditionRoom() {
    final plan = ExpeditionRoom(expedition!);
    expeditionRoom = plan;
    expeditionDoorProgress = 0;
    map = MapComponent.expedition(plan.bounds.size, currentArena, plan.solids);
  }

  Vector2 _expeditionEntrance({bool atGate = false}) {
    final room = expeditionRoom!;
    return Vector2(
      room.entrance.dx,
      atGate ? room.bounds.bottom - 30 : room.entrance.dy,
    );
  }

  void _replaceExpeditionWorld(Vector2 position) {
    final aim = myPlayer.aimDirection.clone();
    final movement = myPlayer.lastMovement.clone();
    resetInput();
    _retirePracticeBosses();
    for (final enemy in _enemies.toList()) {
      _retirePracticeActor(enemy);
    }
    _enemies.clear();
    _expeditionDropGuards.clear();
    _expeditionDropExitShown = false;
    supplyDrops.reset(expedition!.seed ^ 0x51a7);
    _syncSupplyArt(false);
    _spawnWarnings.clear();
    crowdOccupancy.clear();
    minionNavigation.clear();
    enemyTactics.clear();
    _temporaryCoverRouter.clear();
    _navigationPositions.clear();
    _navigationOwners.clear();
    _navigationPlayerPosition = null;
    _navigationLastDt = 0;
    _coins.clear();
    _projectiles.clear();
    _hostileProjectiles.clear();
    _effects.clear();
    _fires.clear();
    _mines.clear();
    _hazards.clear();
    _bursts.clear();
    _bossAttacks.clear();
    weakPoints.clear();
    if (expedition!.generator < 8) {
      supportCombat.clear();
    } else if (expedition!.phase == ExpeditionPhase.combat) {
      final runtime = supportCombat.runtime;
      runtime.units.removeWhere(
        (unit) => unit.card.family == SupportFamily.sentry,
      );
      runtime.rounds.clear();
      supportCombat.traces.clear();
      if (!gameNotifier.support.pending.any(
        (card) => card.family == SupportFamily.sentry,
      )) {
        gameNotifier.support.busy.remove(SupportFamily.sentry.name);
      }
    }
    _arenaAudio?.stopMachines();
    _upgradePulsePending = false;
    upgradePresentation.cancel();
    damageFeedback.reset();
    director = EncounterDirector();
    camera.viewfinder.zoom = 1;

    world = _CombatWorld(this);
    _configureExpeditionRoom();
    _configureArenaGeometry();
    arenaMachines = _createArenaMachines();
    world.add(map);
    _mountRoom(position);
    myPlayer.aimDirection.setFrom(aim);
    myPlayer.lastMovement.setFrom(movement);
    _updateCamera();
    revision.value++;
  }

  PositionComponent _createExpeditionEnemy(String id, Vector2 position) =>
      switch (id) {
        'miniWalker' => ExpeditionWalker(position: position),
        'miniDemon' => ExpeditionVeteranEnemy(
          ExpeditionVeteran.miniDemon,
          position: position,
        ),
        'miniAriet' => ExpeditionVeteranEnemy(
          ExpeditionVeteran.miniAriet,
          position: position,
        ),
        'scorpion' => EnemyComponent(position: position),
        'mummy' => Enemy2Component(position: position),
        'ranged' => Enemy3Component(position: position),
        _ => ArenaEnemy(EnemyKind.values.byName(id), position: position),
      };

  bool expeditionMiniWalkerSiteClear(Vector2 point) {
    final main = activeBoss;
    return main is! WalkerBoss ||
        main.combatHealth.isDead ||
        (point.length >= 330 && point.distanceTo(main.position) >= 340);
  }

  bool _stageExpeditionEnemy(
    String id,
    Vector2 position, {
    bool restoring = false,
    bool dropGuard = false,
  }) {
    final enemy = _createExpeditionEnemy(id, position);
    if (!reserveEnemySpace(
      enemy,
      minPlayerDistance: restoring
          ? 0
          : dropGuard
          ? 135
          : 230,
    )) {
      return false;
    }
    if (!restoring &&
        enemy is ExpeditionWalker &&
        !expeditionMiniWalkerSiteClear(enemy.position)) {
      crowdOccupancy.forget(enemy);
      return false;
    }
    _enemies.add(enemy);
    if (dropGuard) _expeditionDropGuards.add(enemy);
    world.add(SpawnWarning(game: this, enemy: enemy));
    return true;
  }

  bool _stageExpeditionPackMember(String id, Expedition state) {
    final interior = map.bounds.interior.deflate(96);
    final chamber = expeditionRoom!.chamber;
    final rotation = switch (chamber) {
      ExpeditionChamber.gallery =>
        (state.spawned.isEven ? 0 : 3) + 4 * (state.spawned % 3),
      ExpeditionChamber.service => state.spawned % 4,
      ExpeditionChamber.crossing =>
        (state.spawned.isEven ? 3 : 12) + state.spawned % 2,
      ExpeditionChamber.court ||
      null => state.random(3).nextInt(16) + state.spawned * 7,
    };
    // Rotate the approach, then consider the remaining authored grid points.
    // The distance check uses the actual player position and current bodies.
    final anchors = [
      for (var attempt = 0; attempt < 16; attempt++)
        Vector2(
          interior.left + interior.width * ((rotation + attempt) % 4) / 3,
          interior.top +
              interior.height * (((rotation + attempt) % 16) ~/ 4) / 3,
        ),
    ];
    if (state.generator >= 5 && state.region.index == 0 && state.room < 3) {
      // Bring the first groups into view from a few body lengths away.
      double distanceFromApproach(Vector2 point) =>
          (point.distanceTo(myPlayer.position) - 430).abs();
      anchors.sort(
        (a, b) => distanceFromApproach(a).compareTo(distanceFromApproach(b)),
      );
    } else if (state.generator >= 4) {
      final lead = myPlayer.position + movementIntent * 330;
      final flank = (state.bossRoom ? state.bossAdds : state.spawned).isEven
          ? Vector2(-movementIntent.y, movementIntent.x)
          : Vector2(movementIntent.y, -movementIntent.x);
      final focus = lead + flank * 250;
      anchors.sort((a, b) {
        double score(Vector2 point) {
          final distance = point.distanceTo(myPlayer.position);
          return point.distanceToSquared(focus) +
              (distance < 250 ? 3000000 : 0) +
              (distance > 620 ? 250000 : 0);
        }

        return score(a).compareTo(score(b));
      });
    }
    for (final spawn in anchors) {
      if (geometry.obstacles.any(
        (solid) => solid.inflate(55).contains(spawn.toOffset()),
      )) {
        continue;
      }
      if (id == 'miniWalker' && !expeditionMiniWalkerSiteClear(spawn)) continue;
      if (_stageExpeditionEnemy(id, spawn)) return true;
    }
    return false;
  }

  Offset? _expeditionDropSite(Expedition run) {
    final room = expeditionRoom!;
    final area = map.bounds.interior.deflate(150);
    final sites = [
      for (final x in [-.7, -.35, 0.0, .35, .7])
        for (final y in [-.6, -.25, .2, .6])
          Offset(
            area.center.dx + area.width * x / 2,
            area.center.dy + area.height * y / 2,
          ),
    ]..shuffle(run.random(12));
    return sites
        .where(
          (site) =>
              (site - room.entrance).distance >= 245 &&
              !geometry.solids.any((solid) => solid.inflate(95).contains(site)),
        )
        .firstOrNull;
  }

  void _stageDropGuards(Expedition run, Offset site) {
    final roll = run.random(14);
    final angle = roll.nextDouble() * pi * 2;
    final roles = [
      EnemyKind.scorpion,
      EnemyKind.mummy,
      run.region == ExpeditionRegion.breach
          ? EnemyKind.ranged
          : EnemyKind.runner,
    ]..shuffle(roll);
    while (run.dropGuards < roles.length) {
      final slot = run.dropGuards;
      var staged = false;
      for (var probe = 0; probe < 12; probe++) {
        final yaw = angle + slot * 2 * pi / 3 + probe * pi / 6;
        final at =
            site + Offset(cos(yaw), sin(yaw)) * (180 + 30.0 * (probe % 3));
        if (!map.bounds.interior.deflate(55).contains(at) ||
            geometry.solids.any((solid) => solid.inflate(55).contains(at))) {
          continue;
        }
        if (_stageExpeditionEnemy(
          roles[slot].name,
          Vector2(at.dx, at.dy),
          dropGuard: true,
        )) {
          staged = true;
          break;
        }
      }
      if (!staged) return;
      run.dropGuards++;
    }
  }

  void _advanceExpeditionSupply(double dt, Expedition run) {
    if (!run.supplyRoom) return;
    if (!run.dropStarted && run.spawned < 2) return;
    if (run.dropStarted && supplyDrops.drop == null) return;
    if (!run.dropStarted && supplyDrops.previous == null) {
      supplyDrops.nextIn = 0;
    }
    if (_supplyArtLoading) return;
    final before = supplyDrops.drop?.phase;
    supplyDrops.advance(
      dt,
      player: myPlayer.position.toOffset(),
      pickPosition: () => _expeditionDropSite(run),
      onWarning: () {
        run.dropStarted = true;
        audio.play('supply_incoming.wav');
      },
      onLand: (site) {
        showGroundImpact(site, strength: 11, attenuate: true);
        audio.play('supply_land.wav');
        _stageDropGuards(run, site);
      },
      onReward: _offerExpeditionDrop,
      onCharge: (step) => audio.play('supply_charge_$step.wav'),
      onBreak: () => audio.play('supply_break.wav'),
    );
    _syncSupplyArt(supplyDrops.drop != null);
    if (before != supplyDrops.drop?.phase) {
      revision.value++;
    }
    if (supplyDrops.drop case final drop?
        when drop.phase == SupplyPhase.active) {
      _stageDropGuards(run, drop.position);
    }
  }

  bool _offerExpeditionDrop() {
    final run = expedition!;
    final roll = run.random(15);
    final progress = gameNotifier.support;
    final weapons = WeaponType.values
        .where(
          (weapon) =>
              weapon != loadout.weapon &&
              preferences.profile.weaponUnlocked(weapon),
        )
        .toList();
    final specials = [
      for (final family in SupportFamily.values)
        if (!progress.busy.contains(family.name) &&
            !progress.banned.contains(family.name))
          SupportCard(
            family,
            min(supportMaxTier, (progress.tiers[family.name] ?? 0) + 1),
            mount: family == SupportFamily.sentry && roll.nextBool()
                ? 'burstRifle'
                : 'carbine',
          ).id,
      if (weapons.isNotEmpty)
        'weapon:${weapons[roll.nextInt(weapons.length)].name}',
    ];
    final boons = gameNotifier.expeditionChoices.toList()..shuffle(roll);
    run.dropSpecial = specials.isEmpty
        ? 'repair'
        : specials[roll.nextInt(specials.length)];
    run.dropBoons = boons.take(2).toList();
    resetInput();
    audio.play('supply_claim.wav');
    // SupplyDrops marks the pod opened before the durable snapshot is written.
    scheduleMicrotask(() => unawaited(commitExpedition()));
    return true;
  }

  void skipExpeditionDrop() {
    if (!expeditionDropCanSkip) return;
    supplyDrops.drop = null;
    _syncSupplyArt(false);
    revision.value++;
  }

  Future<void> claimExpeditionDrop(String id) async {
    final run = expedition!;
    if (!expeditionDropOffer ||
        expeditionSaving ||
        expeditionCommitFailed ||
        expeditionDropClaiming ||
        gameState.gameplayState != GameplayState.playing) {
      return;
    }
    final choice = run.dropBoons.where((boon) => boon.name == id).firstOrNull;
    if (choice == null && id != run.dropSpecial) return;
    expeditionDropClaiming = true;
    revision.value++;
    try {
      if (choice != null) {
        if (!gameNotifier.applyExpeditionBoon(choice)) return;
      } else if (SupportCard.read(id) case final support?) {
        if (!gameNotifier.applyExpeditionSupport(support)) return;
      } else if (id == 'repair') {
        gameNotifier.heal(2);
      } else {
        final weapon = WeaponType.values.byName(id.substring(7));
        if (!await _changeRunWeapon(weapon, fromDrop: true)) return;
      }
      if (disposed || expedition != run) return;
      run.dropSpecial = null;
      run.dropBoons = const [];
      await commitExpedition();
    } catch (error) {
      debugPrint('Expedition airdrop reward unavailable: $error');
    } finally {
      expeditionDropClaiming = false;
      if (!disposed) revision.value++;
    }
  }

  void _advanceExpedition(double dt, Vector2 before) {
    final state = expedition!;
    if (state.phase == ExpeditionPhase.exit) {
      if (expeditionDoorProgress < 1) return;
      final room = expeditionRoom!;
      for (var i = 0; i < room.doors.length; i++) {
        if (ArenaGeometry.crosses(before, myPlayer.position, room.door(i))) {
          state.next = i;
          unawaited(commitExpedition());
          return;
        }
      }
      return;
    }
    if (state.phase != ExpeditionPhase.combat) return;
    state.clock += dt;
    state.flashpointCooldown = max(0, state.flashpointCooldown - dt);
    if (state.bossRoom) {
      if (bosses.isEmpty && !defeatedBosses.contains(state.boss.name)) {
        spawnBoss(state.boss, center: state.generator >= 4);
        state.spawned = bosses.isEmpty ? 0 : 1;
      } else if (state.generator >= 4 && activeBoss != null) {
        final boss = activeBoss! as CombatEnemy;
        if (boss.isLoaded &&
            !boss.combatHealth.isDead &&
            state.bossAdds < state.bossReinforcements &&
            (state.bossAdds == 0
                ? state.clock >= 10 ||
                      (state.clock >= 4 && boss.combatHealth.fraction <= .6)
                : state.clock >= 2)) {
          final miniWalker = state.generator >= 7
              ? state.boss == BossKind.walker
              : state.bossAdds == 0;
          if (_stageExpeditionPackMember(
            miniWalker ? 'miniWalker' : EnemyKind.runner.name,
            state,
          )) {
            state.bossAdds++;
            state.clock = 0;
          }
        }
      } else if (bosses.isEmpty &&
          !_enemies.any(_expeditionEnemyAlive) &&
          !world.children.whereType<BossDeparture>().any(
            (actor) => !actor.isRemoving,
          )) {
        if (state.finalRegion) {
          state.phase = ExpeditionPhase.victory;
          gameNotifier.finishExpedition();
        } else {
          state.capstones = gameNotifier.expeditionCapstones.take(2).toList();
          final picks =
              gameNotifier.expeditionChoices
                  .where(ExpeditionBoon.arsenal.pool.contains)
                  .toList()
                ..shuffle(state.random(4));
          state.draft = [picks.firstOrNull ?? PowerUp.salvage];
          if (state.generator >= 9) {
            final ranks =
                state.signatures.keys
                    .where((card) => state.signatures[card]! < 3)
                    .toList()
                  ..shuffle(state.random(25));
            state.signatureDraft = ranks.take(2).toList();
          }
          state.phase = ExpeditionPhase.reward;
          _replaceExpeditionWorld(myPlayer.position.clone());
          unawaited(commitExpedition());
        }
      }
      return;
    }
    _advanceArenaMachines(dt);
    if (gameState.gameplayState != GameplayState.playing) return;
    if (state.trapped) {
      state.hazardClock += dt;
      if (state.hazardClock >= 4.8) {
        state.hazardClock = 0;
        final here = myPlayer.position.toOffset();
        final plates = expeditionRoom!.trapPlates.toList()
          ..sort(
            (a, b) => (a - here).distanceSquared.compareTo(
              (b - here).distanceSquared,
            ),
          );
        if (plates.isNotEmpty) {
          final plate = plates.first;
          addHostileArea(
            Vector2(plate.dx, plate.dy),
            radius: 130,
            warning: .95,
            active: .65,
            cause: 'Pressure trap',
          );
        }
      }
    } else if (state.region == ExpeditionRegion.floodworks) {
      state.hazardClock += dt;
      if (state.hazardClock >= 10) {
        state.hazardClock = 0;
        final y = state.spawned.isEven ? -180.0 : 140.0;
        addHostileArea(
          Vector2(0, y),
          radius: 180,
          warning: 1.7,
          active: 2.1,
          cause: 'Sluice surge',
        );
      }
    }
    _advanceExpeditionSupply(dt, state);
    if (expeditionDropOffer) return;
    final pack = state.pack;
    if (state.spawned < pack.length) {
      final chamber = expeditionRoom!.chamber;
      final batch = chamber == ExpeditionChamber.service ? 3 : 4;
      final startsWave = state.spawned > 0 && state.spawned % batch == 0;
      final tighter = state.generator >= 4;
      final cap = tighter ? (state.room < 2 ? 6 : 9) : (state.room < 2 ? 5 : 7);
      final ramped = state.generator >= 5;
      final interval = ramped
          ? state.spawnInterval
          : startsWave && chamber != null
          ? (tighter ? .38 : .9)
          : .22;
      final limit = ramped
          ? state.waveLimit
          : startsWave && chamber != null && !tighter
          ? 2
          : cap;
      final living = state.generator >= 6
          ? _enemies.where(_expeditionEnemyAlive).length
          : enemyPopulation.arena;
      final waitingForClear =
          state.generator >= 6 &&
          state.spawned > 0 &&
          state.startsWave &&
          living > state.waveCarryover;
      if (!waitingForClear && state.clock >= interval && living < limit) {
        final miniWalker =
            state.generator < 7 &&
            tighter &&
            (ramped
                ? state.region.index >= 1 && state.room >= 1
                : state.room >= 2) &&
            state.spawned == (ramped ? state.waveSize + 1 : 4) &&
            (state.room + state.region.index).isEven;
        if (_stageExpeditionPackMember(
          state.veteran?.name ??
              (miniWalker ? 'miniWalker' : pack[state.spawned].name),
          state,
        )) {
          state.spawned++;
          state.clock = 0;
        }
      }
      return;
    }
    if (_enemies.any(_expeditionEnemyAlive)) return;
    if (expeditionDropCanSkip && !_expeditionDropExitShown) {
      _expeditionDropExitShown = true;
      revision.value++;
    }
    if (supplyDrops.drop case final drop?
        when drop.phase == SupplyPhase.warning ||
            drop.phase == SupplyPhase.falling ||
            drop.phase == SupplyPhase.active) {
      return;
    }
    final eligible = gameNotifier.expeditionChoices;
    final signature = state.rewardSignature;
    if (state.opening && state.generator >= 3 && state.signatures.isEmpty) {
      state.signatureDraft = state.openingSignatures;
    } else if (signature != null &&
        (state.generator >= 3 || state.signatures.isNotEmpty) &&
        (state.signatures[signature] ?? 0) < 3) {
      final hand = <ExpeditionSignature>[signature];
      if (state.generator >= 9 && state.room >= 2 && state.room.isEven) {
        final options =
            (state.generator >= 10
                    ? ExpeditionSignature.values
                    : ExpeditionSignature.firstPass)
                .where(
                  (card) =>
                      card != signature && (state.signatures[card] ?? 0) < 3,
                )
                .toList()
              ..shuffle(state.random(22));
        if (options.isNotEmpty) {
          final partner = options
              .where(
                (card) => ExpeditionFusion.values.any(
                  (fusion) => state.signatures.keys.any(
                    (owned) => fusion.partner(owned) == card,
                  ),
                ),
              )
              .firstOrNull;
          hand.add(
            state.generator >= 10 ? partner ?? options.first : options.first,
          );
        }
      }
      state.signatureDraft = hand;
    }
    if (state.generator >= 10 &&
        !state.opening &&
        state.reward != ExpeditionBoon.repair &&
        state.signatureDraft.isEmpty) {
      final upgradeable =
          state.signatures.keys
              .where((card) => state.signatures[card]! < 3)
              .toList()
            ..shuffle(state.random(26));
      if (upgradeable.isNotEmpty) state.signatureDraft = [upgradeable.first];
    }
    final draft = state.reward.pool.where(eligible.contains).toList()
      ..shuffle(state.random(4));
    if (state.generator >= 10 && state.reward != ExpeditionBoon.repair) {
      final wild =
          eligible
              .where((card) => card != PowerUp.salvage && !draft.contains(card))
              .toList()
            ..shuffle(state.random(27));
      if (draft.length >= 2 && wild.isNotEmpty) draft.insert(1, wild.first);
      if (draft.length < 3) {
        draft.addAll(
          wild.where((card) => !draft.contains(card)).take(3 - draft.length),
        );
      }
    }
    final lead = fusionRecipes
        .where(
          (recipe) =>
              !gameState.fused(recipe.id) &&
              gameState.rank(recipe.first) > 0 &&
              gameState.rank(recipe.second) == 0 &&
              draft.contains(recipe.second),
        )
        .firstOrNull
        ?.second;
    if (lead != null) {
      draft.remove(lead);
      draft.insert(0, lead);
    }
    state.draft = state.signatureDraft.isNotEmpty
        ? draft.take(3 - state.signatureDraft.length).toList()
        : draft.isEmpty
        ? const [PowerUp.salvage]
        : draft.take(3).toList();
    state.phase = ExpeditionPhase.reward;
    _replaceExpeditionWorld(myPlayer.position.clone());
    unawaited(commitExpedition());
  }

  bool _expeditionEnemyAlive(PositionComponent actor) =>
      !actor.isRemoving &&
      !actor.isRemoved &&
      (!actor.isLoaded || !(actor as CombatEnemy).combatHealth.isDead);

  void chooseExpeditionBoon(PowerUp choice) {
    final state = expedition!;
    if (!_canClaimExpeditionReward || !state.draft.contains(choice)) return;
    if (choice == PowerUp.salvage) {
      gameNotifier.heal(
        state.reward == ExpeditionBoon.repair
            ? (gameState.maxHealth * state.release.repairPercent / 100).ceil()
            : 1,
      );
    } else if (!gameNotifier.applyExpeditionBoon(choice)) {
      return;
    }
    _claimExpeditionReward();
  }

  void chooseExpeditionSignature(ExpeditionSignature signature) {
    final run = expedition!;
    final rank = run.signatures[signature] ?? 0;
    if (!_canClaimExpeditionReward ||
        !run.signatureDraft.contains(signature) ||
        rank >= 3) {
      return;
    }
    run.signatures[signature] = rank + 1;
    if (signature == ExpeditionSignature.bloodTax) {
      run.signatureKills = min(
        run.signatureKills,
        ExpeditionSignature.bloodTaxKills(rank + 1) - 1,
      );
    }
    if (signature == ExpeditionSignature.breachCharge) {
      run.breachChargeReady = true;
    }
    if (signature == ExpeditionSignature.coldSnap) run.coldSnapReady = true;
    audio.play('fusion.wav');
    _claimExpeditionReward();
  }

  void forgeExpeditionSynergy() {
    if (!_canClaimExpeditionReward || !expedition!.offersSynergy) return;
    expedition!.synergy = 1;
    audio.play('fusion.wav');
    _claimExpeditionReward();
  }

  void forgeExpeditionFusion(ExpeditionFusion fusion) {
    final run = expedition!;
    if (!_canClaimExpeditionReward || !run.forgeChoices.contains(fusion)) {
      return;
    }
    run.fusions.add(fusion);
    audio.play('fusion.wav');
    _claimExpeditionReward();
  }

  void expeditionDashLanded() {
    final run = expedition;
    if (run == null || run.phase != ExpeditionPhase.combat) return;
    final rank = run.signatures[ExpeditionSignature.thunderstep];
    if (rank != null) {
      if (run.fusions.contains(ExpeditionFusion.arcPrimer)) {
        run.breachChargeReady = true;
        revision.value++;
      }
      if (run.fusions.contains(ExpeditionFusion.liveWire)) {
        run.signatureHits = 3;
      }
      combat.expeditionBurst(
        myPlayer.position,
        radius: 190 + 35.0 * rank,
        damage: 1.4 + (run.generator >= 4 ? 1.4 : .8) * rank,
        targets: rank + 2,
        lightning: true,
      );
    }
    if (run.signatures[ExpeditionSignature.shatterstep] case final rank?) {
      combat.expeditionBurst(
        myPlayer.position,
        radius: 135 + rank * 24,
        damage: 3.0 + rank * 2,
        targets: 5 + rank,
        shove: 45.0 + rank * 28,
        shatterFrozen: run.fusions.contains(ExpeditionFusion.brittleSteel),
      );
      if (run.fusions.contains(ExpeditionFusion.slagTrail)) {
        addFire(BurningGround(position: myPlayer.position.clone(), damage: 2));
      }
    }
    if (run.signatures.containsKey(ExpeditionSignature.quickdraw)) {
      gameNotifier.restorePrimaryUnits(1);
      run.quickdrawReady = true;
      revision.value++;
    }
  }

  void chooseExpeditionCapstone(String id) {
    if (!_canClaimExpeditionReward ||
        !expedition!.capstones.contains(id) ||
        !gameNotifier.applyExpeditionCapstone(id)) {
      return;
    }
    _claimExpeditionReward();
  }

  bool get _canClaimExpeditionReward =>
      expedition!.phase == ExpeditionPhase.reward &&
      !expeditionSaving &&
      !expeditionCommitFailed &&
      gameState.gameplayState == GameplayState.playing;

  void _claimExpeditionReward() {
    final state = expedition!;
    if (state.bossRoom) {
      gameNotifier.heal((gameState.maxHealth * .25).ceil());
    }
    state.draft = const [];
    state.capstones = const [];
    state.signatureDraft = const [];
    final eligible = gameNotifier.expeditionChoices;
    final choices =
        ExpeditionBoon.values
            .where(
              (family) =>
                  family != ExpeditionBoon.repair &&
                  (state.generator >= 10 ||
                      family.index <=
                          (state.generator == 9
                              ? ExpeditionBoon.precision.index
                              : ExpeditionBoon.guard.index)) &&
                  (family.pool.any(eligible.contains) ||
                      (state.generator >= 3 &&
                          family.signature != null &&
                          (state.generator >= 9 ||
                              ExpeditionSignature.legacy.contains(
                                family.signature,
                              )) &&
                          (state.signatures[family.signature] ?? 0) < 3)),
            )
            .toList()
          ..shuffle(state.random(5));
    final active = state.signatures.entries
        .where((entry) => entry.value < 3)
        .map((entry) => entry.key)
        .toList();
    if (state.generator >= 9) active.shuffle(state.random(24));
    if (state.generator >= 10 && state.fusions.isEmpty) {
      final nearForge = active
          .where(
            (card) => ExpeditionFusion.values.any(
              (fusion) =>
                  fusion.partner(card) != null &&
                  (state.signatures[fusion.partner(card)] ?? 0) >= 1,
            ),
          )
          .toList();
      active.removeWhere(nearForge.contains);
      active.insertAll(0, nearForge);
    }
    final activeSignature = active.firstOrNull;
    final preferred = switch (activeSignature) {
      ExpeditionSignature.thunderstep => ExpeditionBoon.storm,
      ExpeditionSignature.flashpoint => ExpeditionBoon.ember,
      ExpeditionSignature.breachCharge => ExpeditionBoon.arsenal,
      ExpeditionSignature.coldSnap => ExpeditionBoon.frost,
      ExpeditionSignature.shatterstep => ExpeditionBoon.impact,
      ExpeditionSignature.fuseLink => ExpeditionBoon.ordnance,
      ExpeditionSignature.bloodTax => ExpeditionBoon.guard,
      ExpeditionSignature.deadeye => ExpeditionBoon.precision,
      ExpeditionSignature.ironCurtain => ExpeditionBoon.screen,
      ExpeditionSignature.thermite => ExpeditionBoon.thermite,
      ExpeditionSignature.backlash => ExpeditionBoon.retaliation,
      ExpeditionSignature.quickdraw => ExpeditionBoon.quickdraw,
      null => state.reward,
    };
    final continuation = preferred.signature != null && activeSignature != null
        ? preferred
        : choices.contains(preferred)
        ? preferred
        : choices.firstOrNull;
    final alternatives = choices
        .where((choice) => choice != continuation)
        .toList();
    if (state.generator >= 10) {
      final partners = {
        for (final owned in state.signatures.keys)
          for (final recipe in ExpeditionFusion.values)
            if (recipe.partner(owned) case final partner?
                when (state.signatures[partner] ?? 0) < 2)
              partner,
      };
      // Stable partition preserves the seeded ordering within each group.
      final preferred = alternatives
          .where((family) => partners.contains(family.signature))
          .toList();
      alternatives.removeWhere(preferred.contains);
      alternatives.insertAll(0, preferred);
    }
    final other = state.generator >= 9
        ? alternatives
                  .where(
                    (choice) => choice.signature != continuation?.signature,
                  )
                  .firstOrNull ??
              alternatives.firstOrNull
        : alternatives.firstOrNull;
    state.exits = state.bossRoom || state.room == state.roomCount - 1
        ? const []
        : [
            continuation ?? ExpeditionBoon.repair,
            if (continuation != null &&
                ((state.generator >= 9
                        ? state.random(23).nextInt(4) == 0
                        : state.room.isOdd) ||
                    other == null))
              ExpeditionBoon.repair
            else
              other ?? ExpeditionBoon.arsenal,
          ];
    if (state.exits.length == 2 && state.random(6).nextBool()) {
      state.exits = state.exits.reversed.toList();
    }
    state.phase = ExpeditionPhase.exit;
    unawaited(commitExpedition());
  }

  Future<bool> commitExpedition() async {
    if (expeditionSaving || disposed || !isMounted) return false;
    final state = expedition!;
    final id = runId;
    expeditionSaving = true;
    expeditionCommitFailed = false;
    resetInput();
    revision.value++;
    var saved = await runStore.writeRecovery(checkpoint());
    if (saved && state.terminal) {
      saved = await ExpeditionProgress.shared.record(
        _recordOwner,
        id,
        victory: state.phase == ExpeditionPhase.victory,
        threat: state.threat,
        seconds: gameState.survivalSeconds,
        region: state.region.index,
        boons: [
          ...gameState.ranks.keys.map((boon) => boon.name),
          ...state.signatures.keys.map((card) => card.name),
        ],
        capstones: [
          ...gameState.evolutions,
          ...state.fusions.map((fusion) => fusion.name),
        ],
      );
    }
    if (disposed || !isMounted || id != runId) return false;
    expeditionSaving = false;
    expeditionCommitFailed = !saved;
    saveIssue = saved ? null : 'Expedition could not be saved.';
    if (saved && state.terminal) {
      _settled = true;
      _settlementSaved = true;
    }
    if (saved && state.next != null) {
      expeditionPassage = 0;
    }
    revision.value++;
    return saved;
  }

  void _advanceExpeditionPassage(double dt) {
    const midpoint = RegunGame.expeditionPassageMidpoint;
    const end = .76;
    final before = expeditionPassage!;
    final after = min(end, before + dt);
    expeditionPassage = after;
    if (before < midpoint && after >= midpoint) {
      _enterCommittedExpeditionRoom(throughPassage: true);
    }
    final room = expeditionRoom!;
    if (preferences.reducedMotion) {
      if (after >= midpoint) {
        final entry = room.entrance;
        myPlayer.position.setValues(entry.dx, entry.dy);
      }
    } else if (after < midpoint) {
      final gate = room.doors[expedition!.next!];
      final point = Offset.lerp(
        gate,
        Offset(gate.dx, room.bounds.top + 24),
        after / midpoint,
      )!;
      myPlayer.walkExpeditionPassage(Vector2(point.dx, point.dy), dt);
    } else {
      final entry = room.entrance;
      final start = _expeditionEntrance(atGate: true).toOffset();
      final point = Offset.lerp(
        start,
        entry,
        (after - midpoint) / (end - midpoint),
      )!;
      myPlayer.walkExpeditionPassage(Vector2(point.dx, point.dy), dt);
    }
    _updateCamera();
    if (after >= end) {
      gameNotifier.grantResumeGrace(milliseconds: 650);
      expeditionPassage = null;
      unawaited(saveCheckpoint());
      revision.value++;
    }
  }

  void _enterCommittedExpeditionRoom({bool throughPassage = false}) {
    final state = expedition!;
    final previous = state.region;
    state.advanceRoom();
    final layout = ExpeditionRoom(state);
    final entrance = layout.entrance;
    final y = throughPassage ? layout.bounds.bottom - 30 : entrance.dy;
    _replaceExpeditionWorld(Vector2(entrance.dx, y));
    if (previous != state.region) unawaited(audio.playMusic(currentArena.name));
    if (!throughPassage) unawaited(saveCheckpoint());
  }

  Future<void> _finishExpedition() async {
    if (_settlementSaved) return;
    final state = expedition!;
    if (state.phase != ExpeditionPhase.victory) {
      state.phase = ExpeditionPhase.defeat;
    }
    final id = runId;
    // A terminal snapshot can restore results after a force close. Retry or
    // leaving a settled result retires that slot through the ordinary guard.
    final saved = await commitExpedition();
    if (runId != id || disposed) return;
    _settled = saved;
    _settlementSaved = saved;
    if (isMounted) revision.value++;
  }
}

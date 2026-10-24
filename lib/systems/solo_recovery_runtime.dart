part of '../game.dart';

extension SoloRecoveryRuntime on RegunGame {
  void _recoveryChanged() {
    if (isMounted) revision.value++;
  }

  Future<bool> persistRecovery() async {
    if (recovery.owner != preferences.profileOwner) return false;
    final saved = await runStore.writeRecovery(checkpoint());
    saveIssue = saved
        ? null
        : 'Recovery could not be saved. Retry before leaving.';
    _recoveryChanged();
    return saved;
  }

  Future<Map<String, dynamic>> _recoveryCall(String action) async {
    if (recovery.owner != preferences.profileOwner) {
      throw StateError('Account changed');
    }
    final id = runId, owner = recovery.owner;
    final result =
        await (recoveryTransport ??
            AccountController.shared.soloRecoveryRequest)({
          'action': action,
          'run': runId,
          'epoch': recovery.epoch,
          'seconds': gameState.survivalSeconds,
          'startingScrap': recovery.startingScrap,
        });
    if (runId != id || preferences.profileOwner != owner) {
      throw StateError('Run changed');
    }
    return result;
  }

  Future<void> handleSoloDeath() async {
    if (!recovery.pending &&
        recovery.eligible(gameState.survivalSeconds, loadout.training)) {
      recovery.stage = 'offered';
    }
    if (!recovery.pending) {
      await settleRun();
      return;
    }
    _recoveryChanged();
    await checkSoloRecovery();
  }

  Future<void> _recoveryAction(Future<void> Function() action) async {
    if (recovery.busy) return;
    recovery.busy = true;
    recovery.available = false;
    _recoveryChanged();
    try {
      await action();
    } catch (e) {
      recovery.message = e is AccountError
          ? e.message
          : 'Connect to confirm recovery. Retry or safely end this run.';
    } finally {
      recovery.busy = false;
      _recoveryChanged();
    }
  }

  Future<void> _acceptRecoveryResponse(Map<String, dynamic> data) async {
    final raw = data['revive'];
    if (raw is! Map || raw['run'] != runId) {
      recovery.message =
          'Purchase not confirmed. Check again or cancel before ending.';
      return;
    }
    if (raw['epoch'] is! String) {
      throw const FormatException('Invalid recovery receipt');
    }
    recovery.epoch = raw['epoch'];
    if (raw['state'] == 'activated' && recovery.stage != 'prepared') {
      recovery.continued = true;
      recovery.stage = 'ended';
      recovery.message = 'This run has already used its revive.';
      await persistRecovery();
      await settleRun();
      return;
    }
    if (raw['paid'] == true) {
      await _completeSoloRecovery();
      return;
    }
    recovery.available =
        raw['state'] == 'offered' && raw['price'] == SoloRecovery.price;
    recovery.message = recovery.available
        ? 'Keep your build. Return with half health, full ammo and brief protection.'
        : 'No revive is available for this run.';
    await persistRecovery();
  }

  Future<void> checkSoloRecovery() => _recoveryAction(() async {
    if (!await persistRecovery()) return;
    recovery.message = 'Checking the account server…';
    _recoveryChanged();
    final data = await _recoveryCall(
      recovery.stage == 'offered' ? 'offer' : 'status',
    );
    if (recovery.pending) await _acceptRecoveryResponse(data);
  });
  Future<void> buySoloRecovery() => _recoveryAction(() async {
    // available is cleared by the lock; stage and the durable quoted epoch guard spend.
    if (recovery.stage != 'offered' || recovery.epoch.isEmpty) return;
    recovery.stage = 'requested';
    if (!await persistRecovery()) {
      recovery.stage = 'offered';
      return;
    }
    recovery.message = 'Confirming 55 Scrap revive…';
    _recoveryChanged();
    await _acceptRecoveryResponse(await _recoveryCall('buy'));
  });
  Vector2 _recoveryPosition() {
    final origin = myPlayer.position.clone();
    for (var i = 0; i < 160; i++) {
      final angle = i * 2.399963229728653;
      final point = i < 100
          ? origin + Vector2(cos(angle), sin(angle)) * (40 * sqrt(i))
          : Vector2(cos(angle), sin(angle)) * (45 * sqrt(i - 100));
      final adjusted = point.clone();
      constrainActor(adjusted, 42, bottomExtent: myPlayer.boundaryFootExtent);
      if (point.distanceToSquared(adjusted) > 1) continue;
      if (liveEnemies.any(
        (e) =>
            e.position.distanceToSquared(point) < pow(crowdRadius(e) + 170, 2),
      )) {
        continue;
      }
      if (_hazards.any(
        (h) =>
            !h.isRemoving &&
            h.position.distanceToSquared(point) < pow(h.radius + 60, 2),
      )) {
        continue;
      }
      if (_bossAttacks.any(
        (a) => !a.isRemoving && a.shape.hits(point, 1, body: 45),
      )) {
        continue;
      }
      return point;
    }
    throw const AccountError(
      'No safe landing yet. Recovery is retained; retry.',
    );
  }

  Future<void> _completeSoloRecovery() async {
    if (recovery.stage != 'prepared') {
      final position = _recoveryPosition();
      recovery.continued = true;
      recovery.stage = 'prepared';
      gameNotifier.prepareSoloRevive();
      myPlayer.position.setFrom(position);
      for (final shot in _hostileProjectiles.toList()) {
        if (shot.position.distanceToSquared(position) <= 220 * 220) {
          shot.removeFromParent();
        }
      }
    }
    // The exact healed build/position and used flag are on both disk copies
    // before activation. Combat cannot resume from a mere debit response.
    if (!await persistRecovery()) return;
    final data = await _recoveryCall('activate');
    if (data['revive']?['state'] != 'activated' ||
        data['revive']?['run'] != runId) {
      throw const AccountError('Recovery confirmation incomplete. Retry.');
    }
    recovery.stage = 'alive';
    if (!await persistRecovery()) {
      recovery.stage = 'prepared';
      return;
    }
    damageFeedback.reset();
    gameNotifier.grantResumeGrace(milliseconds: 2000);
    resetInput();
    playerEntrance.begin(
      respawn: true,
      reducedMotion: preferences.reducedMotion,
      camera: camera.viewfinder.position,
      target: myPlayer.position,
    );
    recovery.message = '';
    if (applicationActive) resumeGame();
  }

  Future<void> endRecoveryRun() async {
    if (recovery.stage == 'offered' && recovery.busy) {
      recovery.stage = 'ended';
      _recoveryChanged();
      if (await persistRecovery()) {
        _settlement = settleRun();
        await _settlement;
      }
      return;
    }
    await _recoveryAction(() async {
      if (recovery.stage == 'requested' || recovery.stage == 'prepared') {
        final data = await _recoveryCall('close');
        if (data['revive']?['paid'] == true) {
          await _acceptRecoveryResponse(data);
          return;
        }
        if (data['revive']?['state'] != 'closed') {
          throw const AccountError(
            'Could not safely cancel. Retry when connected.',
          );
        }
      }
      recovery.stage = 'ended';
      if (!await persistRecovery()) return;
      _settlement = settleRun();
      await _settlement;
    });
  }
}

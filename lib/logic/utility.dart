// lib/logic/game_logic.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_state.dart';
import '../models/enemy.dart';
import '../models/item.dart';
import 'enums.dart';
import '../services/leaderboard_service.dart';
import '../models/player.dart';
/// ===================== UTILITIES =====================

double defendCooldownPercent(GameState game) {
  final now = DateTime.now();
  final elapsed = now.difference(game.player.lastDefendTime).inMilliseconds;
  return (elapsed / game.player.defendCooldownMs).clamp(0.0, 1.0);
}

void slideTo({
  required double startX,
  required double targetX,
  required void Function(double) onUpdate,
  required void Function() setStateFn,
  Duration duration = const Duration(milliseconds: 250),
}) {
  final deltaX = targetX - startX;
  const int steps = 15;
  int currentStep = 0;

  Timer.periodic(
    Duration(milliseconds: duration.inMilliseconds ~/ steps),
    (timer) {
      if (currentStep >= steps) {
        onUpdate(targetX);
        setStateFn();
        timer.cancel();
        return;
      }
      onUpdate(startX + deltaX * (currentStep / steps));
      setStateFn();
      currentStep++;
    },
  );
}

/// ===================== COLLISIONS =====================

bool checkCollisionWithEnemy(GameState game, Enemy enemy) {
  // Only hit if player is near ground (same as enemy y)
  const double groundY = 0.8;
  if ((game.player.y - groundY).abs() > 0.1) return false;

  int direction = game.player.x < enemy.x ? 1 : -1;
  double attackFront = game.player.x + direction * attackReach;

  double enemyLeft = enemy.x - enemySolidWidth / 2;
  double enemyRight = enemy.x + enemySolidWidth / 2;

  if (direction == 1) {
    return attackFront >= enemyLeft && attackFront <= enemyRight;
  } else {
    return attackFront <= enemyRight && attackFront >= enemyLeft;
  }
}

bool checkCollisionWithPlayer(GameState game, Enemy enemy) {
  // Only hit if player is on the ground
  const double groundY = 0.8;
  if ((game.player.y - groundY).abs() > 0.02) return false;

  int direction = enemy.x < game.player.x ? 1 : -1;
  double attackFront = enemy.x + direction * attackReach;

  double playerLeft = game.player.x - playerSolidWidth / 2;
  double playerRight = game.player.x + playerSolidWidth / 2;

  if (direction == 1) {
    return attackFront >= playerLeft && attackFront <= playerRight;
  } else {
    return attackFront <= playerRight && attackFront >= playerLeft;
  }
}

bool checkCollisionWithItem(BuildContext context, GameState game, Item item) {
  final screenW = MediaQuery.of(context).size.width;
  final screenH = MediaQuery.of(context).size.height;
  const playerW = 120.0, playerH = 120.0;
  const itemSize = 40.0;

  double playerCX = (game.player.x + 1) / 2 * screenW;
  double itemCX = (item.x + 1) / 2 * screenW;

  double playerCY = 0.8 * screenH;
  double itemCY = item.y * screenH;

  Rect pr = Rect.fromCenter(
    center: Offset(playerCX, playerCY),
    width: playerW,
    height: playerH,
  );

  Rect ir = Rect.fromCenter(
    center: Offset(itemCX, itemCY),
    width: itemSize,
    height: itemSize,
  );

  return pr.overlaps(ir);
}

/// ===================== ACTIONS =====================

void attackPressedFn({
  required GameState game,
  required Map<Enemy, bool> enemyHitMap,
  required bool Function() getWaitingStart,
  required bool Function() getRoundOver,
  required bool Function() getGameOver,
  required bool Function() getShowASprite,
  required void Function(bool) setShowASprite,
  required void Function() setStateFn,
}) {
  if (getWaitingStart() || getRoundOver() || getGameOver()) return;

  // Prevent attacking while jumping
  const double groundY = 0.8;
  if ((game.player.y - groundY).abs() > 0.07) return;

  final now = DateTime.now();
  if (now.difference(game.player.lastAttackTime).inMilliseconds <
      game.player.attackCooldownMs) {
    return;
  }
  game.player.lastAttackTime = now;

  // Show attack sprite briefly
  setShowASprite(true);
  setStateFn();
  Future.delayed(const Duration(milliseconds: 180), () {
    setShowASprite(false);
    setStateFn();
  });

  // Find the hit enemy
  Enemy? hitEnemy;
  for (var enemy in game.enemies) {
    if (!enemy.isAlive) continue;
    if (checkCollisionWithEnemy(game, enemy)) {
      hitEnemy = enemy;
      break;
    }
  }
  if (hitEnemy == null) return;

  // Apply attack
  game.player.attack(hitEnemy);

  // Show hit flash
  enemyHitMap[hitEnemy] = true;
  setStateFn();
  Future.delayed(const Duration(milliseconds: 180), () {
    enemyHitMap[hitEnemy!] = false;
    setStateFn();
  });
}

void defendPressedFn({
  required GameState game,
  required Map<Enemy, bool> enemyHitMap,
  required bool Function() getWaitingStart,
  required bool Function() getRoundOver,
  required bool Function() getGameOver,
  required void Function() setStateFn,
}) {
  if (getWaitingStart() || getRoundOver() || getGameOver()) return;

  final now = DateTime.now();
  if (now.difference(game.player.lastDefendTime).inMilliseconds <
      game.player.defendCooldownMs) {
    return;
  }

  const double defendRange = 0.27;
  const double groundY = 0.8;
  bool matchedAny = false;

  for (var enemy in game.enemies) {
    if (!enemy.isAlive) continue;

    double distance = (enemy.x - game.player.x).abs();
    bool sameHeight = (game.player.y - groundY).abs() < 0.08;

    // Check frontal direction only
    bool inFront = game.player.facingRight
        ? (enemy.x > game.player.x)
        : (enemy.x < game.player.x);

    if (distance > defendRange || !sameHeight || !inFront) continue;

    final pForm = game.player.form;
    bool matched = false;

    if (pForm == FormType.strength && enemy.type == EnemyType.savage) {
      matched = true;
      double direction = game.player.x < enemy.x ? 1 : -1;
      double targetX = (enemy.x + direction * 0.3).clamp(-1.0, 1.0);
      slideTo(
        startX: enemy.x,
        targetX: targetX,
        onUpdate: (val) => enemy.x = val,
        setStateFn: setStateFn,
      );
      enemy.stunnedUntil = DateTime.now().add(const Duration(seconds: 2));
    } else if (pForm == FormType.speed && enemy.type == EnemyType.swift) {
      matched = true;
      double direction = (game.player.x < enemy.x) ? 1 : -1;
      double targetX = (enemy.x + direction * 0.25).clamp(-0.95, 0.95);
      slideTo(
        startX: game.player.x,
        targetX: targetX,
        onUpdate: (val) => game.player.x = val,
        setStateFn: setStateFn,
      );
      Future.delayed(const Duration(milliseconds: 250), () {
        game.player.facingRight = (enemy.x > game.player.x);
        setStateFn();
      });
      enemy.stunnedUntil = DateTime.now().add(const Duration(seconds: 2));
    } else if (pForm == FormType.skill && enemy.type == EnemyType.sharp) {
      enemy.hp -= 5;
      matched = true;
      enemy.stunnedUntil = DateTime.now().add(const Duration(seconds: 2));
    }

    if (matched) {
      matchedAny = true;

      game.player.isDefending = true;
      enemyHitMap[enemy] = true;
      setStateFn();

      Future.delayed(const Duration(milliseconds: 180), () {
        enemyHitMap[enemy] = false;
        setStateFn();
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        game.player.isDefending = false;
        setStateFn();
      });

      game.player.lastDefendTime = now;
      break;
    }
  }

  if (!matchedAny) {
    // Wrong form, stun the player
    game.player.stunnedUntil = DateTime.now().add(const Duration(seconds: 3));
    game.player.lastDefendTime = now;
  }
}

Future<void> logRunOnceFn({
  required GameState game,
  required bool Function() getRunLogged,
  required void Function(bool) setRunLogged,
}) async {
  if (getRunLogged()) return;
  setRunLogged(true); // prevent double logging
  try {
    await LeaderboardService().addEntry(game.wave);
  } catch (_) {
    setRunLogged(false); // allow retry in next frame
  }
}

/// ===================== MAIN LOOP =====================

void gameLoopFn({
  required BuildContext context,
  required GameState game,
  required bool Function() getWaitingStart,
  required void Function(bool) setWaitingStart,
  required bool Function() getRoundOver,
  required void Function(bool) setRoundOver,
  required bool Function() getGameOver,
  required void Function(bool) setGameOver,
  required bool Function() getPlayerHit,
  required void Function(bool) setPlayerHit,
  required bool Function() getKeyLeft,
  required void Function(bool) setKeyLeft,
  required bool Function() getKeyRight,
  required void Function(bool) setKeyRight,
  required bool Function() getKeyAttack,
  required void Function(bool) setKeyAttack,
  required bool Function() getDefendTriggered,
  required void Function(bool) setDefendTriggered,
  required bool Function() getRunLogged,
  required void Function(bool) setRunLogged,
  required Map<Enemy, bool> enemyHitMap,
  required void Function() setStateFn,
  required bool Function() getShowASprite,
  required void Function(bool) setShowASprite,
}) {
  if (getWaitingStart() || getRoundOver() || getGameOver()) return;

  bool needUpdate = false;

  // --- UPDATE PLAYER POSITION (jump + gravity)
  game.player.update(1); // dt = 1 như code gốc
  // --- HANDLE PLAYER INPUT ---
  if (game.player.isStunned) {
    game.player.vx = 0;
    setKeyLeft(false);
    setKeyRight(false);
    setKeyAttack(false);
    setDefendTriggered(false);
  } else {
    double dx = 0;
    if (getKeyLeft() && !getKeyRight()) {
      dx -= 0.02 * game.player.speed;
      game.player.vx -= 0.02 * game.player.speed;
      game.player.facingRight = false;
    } else if (getKeyRight() && !getKeyLeft()) {
      dx += 0.02 * game.player.speed;
      game.player.vx = 0.02 * game.player.speed;
      game.player.facingRight = true;
    } else {
      game.player.vx = 0;
    }

    if (dx != 0) {
      double newX = (game.player.x + dx).clamp(-1.0, 1.0);
      game.player.x = newX;
      needUpdate = true;
    }

    if (getKeyAttack()) {
      attackPressedFn(
        game: game,
        enemyHitMap: enemyHitMap,
        getWaitingStart: getWaitingStart,
        getRoundOver: getRoundOver,
        getGameOver: getGameOver,
        getShowASprite: getShowASprite,
        setShowASprite: setShowASprite,
        setStateFn: setStateFn,
      );
    }

    if (getDefendTriggered()) {
      defendPressedFn(
        game: game,
        enemyHitMap: enemyHitMap,
        getWaitingStart: getWaitingStart,
        getRoundOver: getRoundOver,
        getGameOver: getGameOver,
        setStateFn: setStateFn,
      );
      setDefendTriggered(false); // reset trigger
    }
  }

  // --- ENEMY MOV & ATK LOGIC ---
  for (var enemy in List<Enemy>.from(game.enemies)) {
    if (!enemy.isAlive || enemy.isStunned) continue;

    enemy.facingRight = enemy.x < game.player.x;
    const double approachRange = 0.15;
    double distance = (enemy.x - game.player.x).abs();

    if (distance < 0.05) game.player.hp -= 0.9;

    if (distance > approachRange) {
      double direction = enemy.x < game.player.x ? 1 : -1;
      enemy.x += direction * enemy.speed;
      enemy.state = 'moving';
      needUpdate = true;
      continue;
    } else {
      if (checkCollisionWithPlayer(game, enemy)) {
        final now = DateTime.now();
        if (now.difference(enemy.lastAttackTime).inMilliseconds >=
            enemy.attackCooldownMs) {
          enemy.lastAttackTime = now;
          enemy.attack(game.player);
          setPlayerHit(true);
          needUpdate = true;
          enemy.state = 'attacking';
          Future.delayed(const Duration(milliseconds: 180), () {
            enemy.state = 'idle';
            setPlayerHit(false);
            setStateFn();
          });
        }
      } else {
        // only switch to idle if not moving closer and not attacking
        if (enemy.state == 'moving' && distance > approachRange * 0.9) {
          // stay in moving until close enough
          needUpdate = true;
        } else if (enemy.state != 'attacking') {
          enemy.state = 'idle';
          needUpdate = true;
        }
        // Slight positional nudge so enemies don't get stuck
        double direction = enemy.x < game.player.x ? 1 : -1;
        enemy.x += direction * (enemy.speed * 0.4);
        needUpdate = true;
      }
    }
  }

  // --- HANDLE DEAD ENEMIES ---
  final dead = game.enemies.where((e) => !e.isAlive).toList();
  if (dead.isNotEmpty) {
    for (var d in dead) {
      game.dropPotionAt(d.x);
      enemyHitMap.remove(d);
    }
    game.enemies.removeWhere((e) => !e.isAlive);

    // Spawn next if not reached total in wave
    if (game.spawnedCount < game.totalEnemiesInWave) {
      game.spawnNextEnemy();
    }

    // If all enemies for this wave are done
    if (game.spawnedCount >= game.totalEnemiesInWave && game.enemies.isEmpty) {
      setRoundOver(true);
      setWaitingStart(false);
    }
    needUpdate = true;
  }

  // --- ITEM PICKUP ---
  if (game.items.isNotEmpty) {
    final picked = <Item>[];
    for (var it in game.items) {
      if (checkCollisionWithItem(context, game, it)) {
        it.onPickup(game.player);
        picked.add(it);
        needUpdate = true;
      }
    }
    for (var it in picked) {
      game.items.remove(it);
    }
  }

  // --- CHECK GAME OVER ---
  if (!game.player.isAlive) {
    setKeyAttack(false);
    setDefendTriggered(false);
    setKeyLeft(false);
    setKeyRight(false);

    // log leaderboard (retryable)
    // fire-and-forget
    // ignore: discarded_futures
    logRunOnceFn(
      game: game,
      getRunLogged: getRunLogged,
      setRunLogged: setRunLogged,
    );

    setGameOver(true);
    setRoundOver(true);
    needUpdate = true;
  }

  // Force cooldown bar to update even if player isn't moving
  needUpdate = true;

  if (needUpdate) {
    setStateFn();
  }
}

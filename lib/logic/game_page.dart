// lib/ui/game_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../logic/enums.dart';       
import '../models/player.dart';
import '../models/enemy.dart';
import '../models/item.dart';
import 'enemy_widget.dart';
import '../services/leaderboard_service.dart';
import 'hp_bar.dart';
import 'player_widget.dart';
import '../models/game_state.dart';
import 'dart:io';
import 'dart:math';


class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final GameState game = GameState();
  final FocusNode _focusNode = FocusNode();
  Timer? loopTimer;
  late final AudioPlayer _bgPlayer;
  bool showASprite = false;
  bool waitingStart = true;
  bool roundOver = false;
  bool gameOver = false;
  bool playerHit = false;
  bool keyLeft = false;
  bool keyRight = false;
  bool keyAttack = false;
  bool runLogged = false;
  final Map<Enemy, bool> enemyHitMap = {};
  final Map<Enemy, bool> enemyAttackMap = {};
  bool defendTriggered = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();

    _bgPlayer = AudioPlayer();
    _bgPlayer.setAsset('assets/bg.mp3').catchError((e) {
      debugPrint("Music preload error: $e");
      return null;
    });
    _bgPlayer.setLoopMode(LoopMode.all);

    // Load leaderboard upon app start
    LeaderboardService().load();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loopTimer = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => gameLoop(),
      );
    });
  }

  @override
  void dispose() {
    loopTimer?.cancel();
    _focusNode.dispose();
    _bgPlayer.dispose();
    super.dispose();
  }

  void nextForm() {
    final values = FormType.values;
    int index = values.indexOf(game.player.form);
    index = (index + 1) % values.length;
    setState(() => game.player.changeForm(values[index]));
  }

  void previousForm() {
    final values = FormType.values;
    int index = values.indexOf(game.player.form);
    index = (index - 1 + values.length) % values.length;
    setState(() => game.player.changeForm(values[index]));
  }

  // Start music. Called on Start Game button (user gesture).
  Future<void> _startMusic() async {
    _bgPlayer.play();
  }

  void _logRun() async {
    if (runLogged) return;
    runLogged = true; // prevent double logging
    try {
      await LeaderboardService().addEntry(game.wave);
      // Successfully logged — nothing more to do
    } catch (e) {
      debugPrint("Failed to log run: $e. Will retry next frame.");
      runLogged = false; // allow retry in next gameLoop
    }
  }

  double getDefendCooldownPercent() {
    final now = DateTime.now();
    final elapsed = now.difference(game.player.lastDefendTime).inMilliseconds;
    double pct = (elapsed / game.player.defendCooldownMs).clamp(0.0, 1.0);
    return pct;
  }

  // Animate sliding
  void slideTo({
    required double startX,
    required double targetX,
    required void Function(double) onUpdate,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    final deltaX = targetX - startX;
    const int steps = 15;
    int currentStep = 0;
    Timer.periodic(Duration(milliseconds: duration.inMilliseconds ~/ steps), (
      timer,
    ) {
      if (!mounted || currentStep >= steps) {
        onUpdate(targetX);
        setState(() {});
        timer.cancel();
        return;
      }
      onUpdate(startX + deltaX * (currentStep / steps));
      setState(() {});
      currentStep++;
    });
  }

  void gameLoop() {
    if (!mounted) return;
    if (waitingStart || roundOver || gameOver) return;
    bool needSetState = false;

    // --- UPDATE PLAYER POSITION (jump + gravity) ---
    game.player.update(1); // dt = 1 for simplicity

    // --- HANDLE PLAYER INPUT ---
    if (game.player.isStunned) {
      game.player.vx = 0;
      keyLeft = false;
      keyRight = false;
      keyAttack = false;
      defendTriggered = false;
    } else {
      double dx = 0;
      if (keyLeft && !keyRight) {
        dx -= 0.02 * game.player.speed;
        game.player.vx -= 0.02 * game.player.speed;
        game.player.facingRight = false;
      } else if (keyRight && !keyLeft) {
        dx += 0.02 * game.player.speed;
        game.player.vx = 0.02 * game.player.speed;
        game.player.facingRight = true;
      } else {
        game.player.vx = 0;
      }
      if (dx != 0) {
        double newX = (game.player.x + dx).clamp(-1.0, 1.0);
        game.player.x = newX;
        needSetState = true;
      }
      if (keyAttack) attackPressed();
      if (defendTriggered) {
        defendPressed();
        defendTriggered = false; //reset the trigger
      }
    }

    // --- ENEMY MOV & ATK LOGIC
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
        needSetState = true;
        continue;
      } else {
        if (_checkCollisionWithPlayer(enemy)) {
          final now = DateTime.now();
          if (now.difference(enemy.lastAttackTime).inMilliseconds >=
              enemy.attackCooldownMs) {
            enemy.lastAttackTime = now;
            enemy.attack(game.player);
            playerHit = true;
            needSetState = true;
            enemy.state = 'attacking';
            Future.delayed(const Duration(milliseconds: 180), () {
              if (!mounted) return;
              enemy.state = 'idle';
              setState(() => playerHit = false);
            });
          }
        } else {
          // only switch to idle if not moving closer and not attacking
          if (enemy.state == 'moving' && distance > approachRange * 0.9) {
            // stay in moving until close enough
            needSetState = true;
          } else if (enemy.state != 'attacking') {
            enemy.state = 'idle';
            needSetState = true;
          }
          // Slight positional nudge so enemies don't get stuck if alignment is slightly off
          // This helps them line up for the next attack without complex blocking logic.
          double direction = enemy.x < game.player.x ? 1 : -1;
          enemy.x += direction * (enemy.speed * 0.4);
          needSetState = true;
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
      debugPrint(
        'After cleanup: alive=${game.enemies.where((e) => e.isAlive).length}, '
        'listLen=${game.enemies.length}, '
        'spawnedCount=${game.spawnedCount}',
      );

      // Spawn next if not reached total in wave
      if (game.spawnedCount < game.totalEnemiesInWave) {
        game.spawnNextEnemy();
      }

      // If all enemies for this wave are done
      if (game.spawnedCount >= game.totalEnemiesInWave &&
          game.enemies.isEmpty) {
        roundOver = true;
        waitingStart = false;
      }

      needSetState = true;
    }

    // --- ITEM PICKUP ---
    if (game.items.isNotEmpty) {
      final picked = <Item>[];
      for (var it in game.items) {
        if (_checkCollisionWithItem(it)) {
          it.onPickup(game.player);
          picked.add(it);
          needSetState = true;
        }
      }
      for (var it in picked) {
        game.items.remove(it);
      }
    }

    // --- CHECK GAME OVER ---
    if (!game.player.isAlive) {
      keyAttack = false;
      defendTriggered = false;
      keyLeft = false;
      keyRight = false;
      _logRun();
      gameOver = true;
      roundOver = true;
      needSetState = true;
    }

    // Force cooldown bar to update even if player isn't moving
    needSetState = true;

    if (needSetState && mounted) {
      setState(() {});
      needSetState = false; // reset flag
    }
  }

  bool _checkCollisionWithEnemy(Enemy enemy) {
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

  bool _checkCollisionWithPlayer(Enemy enemy) {
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

  bool _checkCollisionWithItem(Item item) {
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

  // PLAYER ATTACK
  void attackPressed() {
    if (waitingStart || roundOver || gameOver) return;

    // Prevent attacking while jumping
    const double groundY = 0.8;
    if ((game.player.y - groundY).abs() > 0.07) return;
    final now = DateTime.now();
    if (now.difference(game.player.lastAttackTime).inMilliseconds <
        game.player.attackCooldownMs) {
      return;
    }
    game.player.lastAttackTime = now;
    if (!mounted) return;

    // Show attack sprite briefly
    setState(() => showASprite = true);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => showASprite = false);
    });

    // Find the hit enemy
    Enemy? hitEnemy;
    for (var enemy in game.enemies) {
      if (!enemy.isAlive) continue;
      if (_checkCollisionWithEnemy(enemy)) {
        hitEnemy = enemy;
        break;
      }
    }
    if (hitEnemy == null) return;

    // Apply attack
    game.player.attack(hitEnemy);

    // Show hit flash
    enemyHitMap[hitEnemy] = true;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        enemyHitMap[hitEnemy!] = false;
      });
    });
  }

  // DEFEND
  void defendPressed() {
    if (waitingStart || roundOver || gameOver) return;
    final now = DateTime.now();
    if (now.difference(game.player.lastDefendTime).inMilliseconds <
        game.player.defendCooldownMs) {
      return;
    }
    const double defendRange = 0.27;
    const double groundY = 0.8;
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
          duration: const Duration(milliseconds: 250),
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
          duration: const Duration(milliseconds: 250),
        );
        Future.delayed(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          setState(() => game.player.facingRight = (enemy.x > game.player.x));
        });
        enemy.stunnedUntil = DateTime.now().add(const Duration(seconds: 2));
      } else if (pForm == FormType.skill && enemy.type == EnemyType.sharp) {
        enemy.hp -= 5;
        matched = true;
        enemy.stunnedUntil = DateTime.now().add(const Duration(seconds: 2));
      }
      if (matched) {
        game.player.isDefending = true;
        setState(() {});
        enemyHitMap[enemy] = true;
        setState(() {});
        Future.delayed(const Duration(milliseconds: 180), () {
          if (!mounted) return;
          setState(() => enemyHitMap[enemy] = false);
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          game.player.isDefending = false;
          setState(() {});
        });
        game.player.lastDefendTime = now;
        break;
      }
      if (!matched) {
        // Wrong form, stun the player
        game.player.stunnedUntil = DateTime.now().add(
          const Duration(seconds: 3),
        );
        game.player.lastDefendTime = now;
      }
    }
  }

  void startWaveButton() async {
    await _startMusic();
    setState(() {
      runLogged = false;
      waitingStart = false;
      roundOver = false;
      gameOver = false;
      game.startNextWave(incrementWave: false);
    });
  }

  void nextWaveButton() async {
    // ensure music is playing/resumed
    _startMusic();
    setState(() {
      keyAttack = false;
      defendTriggered = false;
      keyLeft = false;
      keyRight = false;
      waitingStart = true;
      roundOver = false;
      gameOver = false;
      game.player.x = -0.8;
      game.player.y = 0.8;
      game.player.vx = 0;
      game.player.vy = 0;
      game.player.facingRight = true;
      game.player.form = FormType.strength;
      game.rng = Random();
      game.startNextWave();
    });
  }

  void restartGameButton() async {
    _startMusic();
    setState(() {
      runLogged = false;
      waitingStart = true;
      roundOver = false;
      gameOver = false;
      game.wave = 1;
      game.player.hp = game.player.maxHp;
      game.player.x = -0.8;
      game.player.y = 0.8;
      game.player.vx = 0;
      game.player.vy = 0;
      game.player.facingRight = true;
      game.player.form = FormType.strength;
      game.rng = Random();
      game.startNextWave(incrementWave: false);
    });
  }

  void showLeaderboard({int? highlightWave}) {
    final entries = LeaderboardService().entries;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) {
        final scrollController = ScrollController();

        // Find index of the most recent entry if we want to highlight
        int highlightIndex = -1;
        if (highlightWave != null) {
          highlightIndex = entries.indexWhere((e) => e.wave == highlightWave);
          if (highlightIndex != -1) {
            // Scroll to highlighted entry after build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              scrollController.animateTo(
                highlightIndex * 60.0, // approximate row height
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            });
          }
        }
        return AlertDialog(
          title: const Text("Leaderboard"),
          content: SizedBox(
            width: double.maxFinite,
            child: entries.isEmpty
                ? const Text("No runs yet.")
                : ListView.builder(
                    controller: scrollController,
                    shrinkWrap: true,
                    itemCount: entries.length,
                    itemBuilder: (_, index) {
                      final e = entries[index];
                      final isHighlighted = index == highlightIndex;
                      return Container(
                        color: isHighlighted
                            ? const Color.fromARGB(102, 255, 255, 0)
                            : Colors.transparent,
                        child: ListTile(
                          leading: Text("#${index + 1}"),
                          title: Text("Wave ${e.wave}"),
                          subtitle: Text(
                            "${e.timestamp.day.toString().padLeft(2, '0')}/"
                            "${e.timestamp.month.toString().padLeft(2, '0')}/"
                            "${e.timestamp.year} "
                            "${e.timestamp.hour.toString().padLeft(2, '0')}:"
                            "${e.timestamp.minute.toString().padLeft(2, '0')}",
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentEnemies = game.enemies;
    return Stack(
      children: [
        // Main game area
        Positioned.fill(
          child: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (KeyEvent event) {
              if (waitingStart || roundOver || gameOver) return;
              if (event is KeyDownEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  keyLeft = true;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  keyRight = true;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                  game.player.jump();
                }
                if (event.logicalKey == LogicalKeyboardKey.space) {
                  defendTriggered = true;
                }
                if (event.logicalKey == LogicalKeyboardKey.keyC) {
                  keyAttack = true;
                }
                if (event.logicalKey == LogicalKeyboardKey.keyX) nextForm();
                if (event.logicalKey == LogicalKeyboardKey.keyZ) previousForm();
              } else if (event is KeyUpEvent) {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  keyLeft = false;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  keyRight = false;
                }
                if (event.logicalKey == LogicalKeyboardKey.keyC) {
                  keyAttack = false;
                }
              }
            },
            child: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset("assets/bg.png", fit: BoxFit.cover),
                  ),

                  // Items
                  for (var item in game.items)
                    Align(
                      alignment: Alignment(item.x, item.y),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            item.onPickup(game.player);
                            game.items.remove(item);
                          });
                        },
                        child: SizedBox(
                          width: 70,
                          height: 70,
                          child: Image.asset(item.asset, fit: BoxFit.contain),
                        ),
                      ),
                    ),

                  // Enemies
                  if (!waitingStart)
                    for (var enemy in currentEnemies)
                      Align(
                        alignment: Alignment(enemy.x, 0.8),
                        child: EnemyWidget(
                          enemy: enemy,
                          hit: enemyHitMap[enemy] ?? false,
                        ),
                      ),

                  // Player
                  if (game.player.hp > 0)
                    Align(
                      alignment: Alignment(game.player.x, game.player.y),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Defend cooldown bar
                          buildDefendBar(getDefendCooldownPercent()),

                          // Player sprite / attack overlay
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              if (!showASprite)
                                PlayerWidget(
                                  player: game.player,
                                  hit: playerHit,
                                  onFormChange: (f) {
                                    setState(() {
                                      game.player.changeForm(f);
                                    });
                                  },
                                ),
                              if (showASprite)
                                SizedBox(
                                  width: 192,
                                  height: 192,
                                  child: Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..scaleByDouble(
                                        game.player.facingRight ? 1.2 : -1.2,
                                        1.2,
                                        1,
                                        1,
                                      ),
                                    child: Image.asset(
                                      game.player.attackAsset,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // UI Info
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Leaderboard Button
                          ElevatedButton(
                            onPressed: () => showLeaderboard(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                            ),
                            child: const Text("Leaderboard"),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            color: Colors.grey,
                            child: Text(
                              "HP: ${game.player.hp.toStringAsFixed(0)}/${game.player.maxHp.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            color: Colors.grey,
                            child: Text(
                              "Form: ${game.player.name}",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            color: Colors.grey,
                            child: Text(
                              "Wave: ${game.wave}",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            color: Colors.grey,
                            child: Text(
                              "Remaining: ${game.totalEnemiesInWave - game.spawnedCount}",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Game Over / Round Over / Start Buttons
                  if (gameOver)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Game Over",
                            style: TextStyle(fontSize: 32, color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => restartGameButton(),
                            child: const Text("Restart"),
                          ),
                        ],
                      ),
                    ),

                  if (roundOver && !gameOver)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Wave ${game.wave} clear!",
                            style: const TextStyle(
                              fontSize: 28,
                              color: Colors.yellow,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => nextWaveButton(),
                            child: const Text("Next Wave"),
                          ),
                        ],
                      ),
                    ),

                  if (waitingStart)
                    Center(
                      child: ElevatedButton(
                        onPressed: () => startWaveButton(),
                        child: const Text("Start Game"),
                      ),
                    ),

                  // ===== MOBILE CONTROLS LEFT=====
                  if (Platform.isAndroid || Platform.isIOS)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Column(
                        children: [
                          // Jump Button
                          GestureDetector(
                            onTap: () {
                              if (!waitingStart && !roundOver && !gameOver) {
                                game.player.jump();
                              }
                            },
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(123, 255, 255, 255),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.arrow_upward,
                                size: 36,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Left & Right buttons row
                          Row(
                            children: [
                              // Left Button
                              GestureDetector(
                                onTapDown: (_) {
                                  if (!waitingStart &&
                                      !roundOver &&
                                      !gameOver) {
                                    setState(() => keyLeft = true);
                                  }
                                },
                                onTapUp: (_) => setState(() => keyLeft = false),
                                onTapCancel: () =>
                                    setState(() => keyLeft = false),
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      123,
                                      255,
                                      255,
                                      255,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_left,
                                    size: 36,
                                    color: Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Right Button
                              GestureDetector(
                                onTapDown: (_) {
                                  if (!waitingStart &&
                                      !roundOver &&
                                      !gameOver) {
                                    setState(() => keyRight = true);
                                  }
                                },
                                onTapUp: (_) =>
                                    setState(() => keyRight = false),
                                onTapCancel: () =>
                                    setState(() => keyRight = false),
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      123,
                                      255,
                                      255,
                                      255,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_right,
                                    size: 36,
                                    color: Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // ===== MOBILE CONTROLS RIGHT=====
                  if (Platform.isAndroid || Platform.isIOS)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Column(
                        children: [
                          // Attack
                          GestureDetector(
                            onTapDown: (_) {
                              if (!waitingStart && !roundOver && !gameOver) {
                                attackPressed();
                              }
                            },
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(123, 255, 0, 0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.flash_on,
                                size: 36,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Defend
                          GestureDetector(
                            onTapDown: (_) {
                              if (!waitingStart && !roundOver && !gameOver) {
                                defendTriggered = true;
                              }
                            },
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(123, 0, 94, 255),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.shield,
                                size: 36,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Switch Form
                          Row(
                            children: [
                              GestureDetector(
                                onTap: previousForm,
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      123,
                                      115,
                                      255,
                                      0,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_left,
                                    color: Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: nextForm,
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      123,
                                      115,
                                      255,
                                      0,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_right,
                                    color: Color.fromARGB(255, 0, 0, 0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

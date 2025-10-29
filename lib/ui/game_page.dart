// lib/ui/game_page.dart
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../logic/enums.dart';
import '../models/enemy.dart';
import 'enemy_widget.dart';
import '../services/leaderboard_service.dart';
import 'hp_bar.dart';
import 'player_widget.dart';
import '../models/game_state.dart';

// === NEW: import file hàm logic
import '../logic/utility.dart';

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

  // ==== State như cũ (giữ nguyên biến) ====
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

    // ==== Start loop: gọi HÀM logic gameLoopFn ====
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loopTimer = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) {
          if (!mounted) return;
          gameLoopFn(
            context: context,
            game: game,
            getWaitingStart: () => waitingStart,
            setWaitingStart: (v) => waitingStart = v,
            getRoundOver: () => roundOver,
            setRoundOver: (v) => roundOver = v,
            getGameOver: () => gameOver,
            setGameOver: (v) => gameOver = v,
            getPlayerHit: () => playerHit,
            setPlayerHit: (v) => playerHit = v,
            getKeyLeft: () => keyLeft,
            setKeyLeft: (v) => keyLeft = v,
            getKeyRight: () => keyRight,
            setKeyRight: (v) => keyRight = v,
            getKeyAttack: () => keyAttack,
            setKeyAttack: (v) => keyAttack = v,
            getDefendTriggered: () => defendTriggered,
            setDefendTriggered: (v) => defendTriggered = v,
            getRunLogged: () => runLogged,
            setRunLogged: (v) => runLogged = v,
            enemyHitMap: enemyHitMap,
            setStateFn: () {
              if (mounted) setState(() {});
            },
            getShowASprite: () => showASprite,
            setShowASprite: (v) => showASprite = v,
          );
        },
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

        int highlightIndex = -1;
        if (highlightWave != null) {
          highlightIndex =
              entries.indexWhere((e) => e.wave == highlightWave);
          if (highlightIndex != -1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              scrollController.animateTo(
                highlightIndex * 60.0,
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
                  // Giống hành vi cũ: chỉ bật flag, loop sẽ xử lý attack
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
                        alignment: const Alignment(0, 0.8),
                        child: Align(
                          alignment: Alignment(enemy.x, 0.8),
                          child: EnemyWidget(
                            enemy: enemy,
                            hit: enemyHitMap[enemy] ?? false,
                          ),
                        ),
                      ),

                  // Player
                  if (game.player.hp > 0)
                    Align(
                      alignment:
                          Alignment(game.player.x, game.player.y),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Defend cooldown bar (GỌI HÀM logic)
                          buildDefendBar(defendCooldownPercent(game)),

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
                                      ..scale(
                                        game.player.facingRight ? 1.2 : -1.2,
                                        1.2,
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
                                onTapUp: (_) =>
                                    setState(() => keyLeft = false),
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
                                // Mobile attack gọi ngay hàm (y như code gốc)
                                attackPressedFn(
                                  game: game,
                                  enemyHitMap: enemyHitMap,
                                  getWaitingStart: () => waitingStart,
                                  getRoundOver: () => roundOver,
                                  getGameOver: () => gameOver,
                                  getShowASprite: () => showASprite,
                                  setShowASprite: (v) =>
                                      setState(() => showASprite = v),
                                  setStateFn: () {
                                    if (mounted) setState(() {});
                                  },
                                );
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
                                defendTriggered = true; // loop sẽ xử lý
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
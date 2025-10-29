import 'dart:math';
import '../logic/enums.dart';
import 'player.dart';
import 'enemy.dart';
import 'item.dart';
// ==== UTILITY FUNCS ====

// ==== GAME STATE ====
// ==== GAME STATE ====
// ==== GAME STATE ====
// ==== GAME STATE ====
class GameState {
  final Player player = Player();
  List<Enemy> enemies = [];
  List<Item> items = [];
  int wave = 1;
  int spawnedCount = 0; // how many spawned this wave
  Random rng = Random();
  int get totalEnemiesInWave => wave;
  void startNextWave({bool incrementWave = true}) {
    if (incrementWave) wave++;
    enemies.clear();
    items.clear();
    spawnedCount = 0;
    player.hp = (player.hp + player.maxHp * 0.3).clamp(0, player.maxHp);
    spawnNextEnemy(); // start wave with one enemy
  }

  void spawnNextEnemy() {
    if (spawnedCount >= totalEnemiesInWave) return;
    final et = EnemyType.values[rng.nextInt(EnemyType.values.length)];
    const double spawnX = 0.8;
    enemies.add(Enemy(et, x: spawnX));
    spawnedCount++;
  }

  void dropPotionAt(double enemyX) {
    if (rng.nextDouble() < 0.5) {
      double offset = (rng.nextDouble() - 0.5) * 0.1;
      double xPos = (enemyX + offset).clamp(-0.9, 0.9);
      double yPos = 0.9;
      items.add(
        Item(
          "assets/potion.png",
          (player) => player.hp = (player.hp + 30).clamp(0, player.maxHp),
          x: xPos,
          y: yPos,
        ),
      );
    }
  }
}

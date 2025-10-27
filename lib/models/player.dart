import '../logic/enums.dart';
import '../logic/advantage_logic.dart';
import 'enemy.dart';
import 'character.dart';

const double playerSolidWidth = 0.18; // solid collision
const double attackReach = 0.15;



// interface attack
abstract class Attack {
  void attack(dynamic target);
}

class Player extends Character implements Attack {
  FormType form;
  double y;
  double vx; // horizontal velocity
  double vy; // vertical velocity
  bool isDefending = false;
  DateTime lastDefendTime = DateTime.fromMillisecondsSinceEpoch(0);
  final int defendCooldownMs = 3300;
  Player()
    : form = FormType.strength,
      y = 0.8,
      vx = 0,
      vy = 0,
      super(x: -0.8, hp: 100, maxHp: 100);

  void changeForm(FormType f) => form = f;

  // Player-specific getter shortcuts
  String get name => form.name;
  String get jumpAsset => form.jumpAsset;
  String get defendAsset => form.defendAsset;
  @override
  String get idleAsset => form.idleAsset;
  @override
  String get moveAsset => form.moveAsset;
  @override
  String get attackAsset => form.attackAsset;
  @override
  double get speed => form.speed;
  @override
  int get attackCooldownMs => form.attackCooldownMs;

  void jump() {
    if (y >= 0.8) {
      // only jump if on ground
      vy = -0.07; // upward impulse
    }
  }

  void update(double dt) {
    const double gravity = 0.003;
    vy += gravity * dt;
    y += vy * dt;
    if (y > 0.8) {
      // clamp to ground
      y = 0.8;
      vy = 0;
    }
  }

  @override
  void attack(dynamic target) {
    if (target is Enemy) {
      //Specialized mechanic for sharp(green)-type enemy
      if (target.type == EnemyType.sharp && !target.isStunned) {
        hp -= 5;
        return; // skip damaging the enemy
      }

      // Normal attack logic for other enemies or green enemy after stunned
      target.hp -= 10 * matchupMultiplier(form, target.type);
    }
  }
}


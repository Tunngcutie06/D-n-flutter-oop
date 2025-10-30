import 'package:flutter_application_1/models/player.dart';
import '../logic/matchups.dart';
import '../logic/enums.dart';
import 'character.dart';

const double enemySolidWidth = 0.18;

class Enemy extends Character implements Attack {
  final EnemyType type;
  String state = 'idle';

  Enemy(this.type, {required super.x})
    : super(hp: type.maxHp.toDouble(), maxHp: type.maxHp.toDouble());

  // Enemy-specific getter shortcuts
  @override
  String get idleAsset => type.idleAsset;
  @override
  String get moveAsset => type.moveAsset;
  @override
  String get attackAsset => type.attackAsset;
  @override
  double get speed => type.speed;
  @override
  int get attackCooldownMs => type.attackCooldownMs;

  @override
  void attack(dynamic target) {
    if (target is Player) {
      target.hp -= 10 * matchupMultiplier(target.form, type);
    }
  }
}

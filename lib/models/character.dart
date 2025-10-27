// ==== MODELS ====
abstract class Character {
  double x;
  double _hp;
  final double maxHp;
  bool facingRight = true;
  DateTime stunnedUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime lastAttackTime = DateTime.fromMillisecondsSinceEpoch(0);
  Character({required this.x, required double hp, required this.maxHp})
    : _hp = hp;
  double get hp => _hp;
  set hp(double value) => _hp = value.clamp(0, maxHp);
  bool get isAlive => _hp > 0;
  bool get isStunned => DateTime.now().isBefore(stunnedUntil);
  String get idleAsset;
  String get moveAsset;
  String get attackAsset;
  double get speed;
  int get attackCooldownMs;
}


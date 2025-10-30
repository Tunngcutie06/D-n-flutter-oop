import 'package:flutter/material.dart';
import '../models/enemy.dart';
import 'stat_bar.dart';

class EnemyWidget extends StatelessWidget {
  final Enemy enemy;
  final bool hit;
  const EnemyWidget({super.key, required this.enemy, required this.hit});

  @override
  Widget build(BuildContext context) {
    String spritePath;
    if (enemy.isStunned) {
      spritePath = enemy.idleAsset;
    } else {
      switch (enemy.state) {
        case 'attacking':
          spritePath = enemy.attackAsset;
          break;
        case 'moving':
          spritePath = enemy.moveAsset;
          break;
        case 'idle':
        default:
          spritePath = enemy.idleAsset;
          break;
      }
    }

    ColorFilter colorFilter = enemy.isStunned
        ? const ColorFilter.mode(
            Color.fromARGB(255, 123, 123, 123),
            BlendMode.modulate,
          )
        : (hit
              ? const ColorFilter.mode(
                  Color.fromARGB(255, 180, 180, 180),
                  BlendMode.modulate,
                )
              : const ColorFilter.mode(Colors.transparent, BlendMode.multiply));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scaleByDouble(enemy.facingRight ? -1 : 1, 1, 1, 1),
            child: ColorFiltered(
              colorFilter: colorFilter,
              child: Image.asset(spritePath, fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 8),
        buildHpBar(enemy.hp, enemy.maxHp),
      ],
    );
  }
}

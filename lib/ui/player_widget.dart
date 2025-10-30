import 'package:flutter/material.dart';
import '../models/player.dart';
import '../logic/enums.dart';
import 'stat_bar.dart';


class PlayerWidget extends StatelessWidget {
    final Player player;
  final bool hit;
  final ValueChanged<FormType> onFormChange;
  const PlayerWidget({
    super.key,
    required this.player,
    required this.hit,
    required this.onFormChange,
  });

  @override
  Widget build(BuildContext context) {
    String spritePath;

    // Priority-wise
    if (player.isStunned) {
      spritePath = player.idleAsset;
    } else if (player.isDefending) {
      spritePath = player.defendAsset;
    } else if ((player.y - 0.8).abs() > 0.05) {
      spritePath = player.jumpAsset;
    } else if (player.vx.abs() > 0.001) {
      spritePath = player.moveAsset;
    } else {
      spritePath = player.idleAsset;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scaleByDouble(player.facingRight ? 1 : -1, 1, 1, 1),
            child: ColorFiltered(
              colorFilter: player.isStunned
                  ? const ColorFilter.mode(
                      Color.fromARGB(255, 123, 123, 123),
                      BlendMode.modulate,
                    )
                  : (hit
                        ? const ColorFilter.mode(
                            Color.fromARGB(255, 180, 180, 180),
                            BlendMode.modulate,
                          )
                        : const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          )),
              child: Image.asset(spritePath, fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 8),
        buildHpBar(player.hp, player.maxHp),
      ],
    );
  }
}
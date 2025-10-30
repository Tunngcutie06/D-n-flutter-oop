import 'player.dart';

class Item {
  final String asset;
  final void Function(Player) onPickup;
  double x;
  double y;
  Item(this.asset, this.onPickup, {required this.x, required this.y});
}
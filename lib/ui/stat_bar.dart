import 'package:flutter/material.dart';

// ==== UI Helpers ====
Widget buildHpBar(double hp, double maxHp) {
  return Container(
    height: 12,
    width: 120,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white),
      color: Colors.grey.shade800,
    ),
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: (hp / maxHp).clamp(0, 1),
      child: Container(color: Colors.green),
    ),
  );
}

Widget buildDefendBar(double pct) {
  return Container(
    width: 100,
    height: 8,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white),
      color: Colors.grey.shade800,
    ),
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: pct,
      child: Container(color: Colors.blueAccent),
    ),
  );
}
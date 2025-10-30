import 'enums.dart';


// ==== MATCHUP LOGIC ====
double matchupMultiplier(FormType p, EnemyType e) {
  const Map<FormType, Map<EnemyType, double>> multipliers = {
    FormType.strength: {
      EnemyType.savage: 0.9,
      EnemyType.swift: 0.33,
      EnemyType.sharp: 1.8,
    },
    FormType.speed: {
      EnemyType.savage: 1.2,
      EnemyType.sharp: 0.6,
      EnemyType.swift: 0.21,
    },
    FormType.skill: {
      EnemyType.savage: 0.27,
      EnemyType.swift: 1.5,
      EnemyType.sharp: 1.5,
    },
  };
  return multipliers[p]?[e] ?? 1.0;
}
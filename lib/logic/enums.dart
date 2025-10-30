// ==== ENUMS ====
enum FormType { strength, speed, skill }

enum EnemyType { savage, swift, sharp }

// ==== EXTENSIONS (assets + names) ====
extension FormTypeExt on FormType {
  String get idleAsset {
    switch (this) {
      case FormType.strength:
        return "assets/p_red.png";
      case FormType.speed:
        return "assets/p_blue.png";
      case FormType.skill:
        return "assets/p_green.png";
    }
  }

  String get moveAsset {
    switch (this) {
      case FormType.strength:
        return "assets/p_red_run.png";
      case FormType.speed:
        return "assets/p_blue_run.png";
      case FormType.skill:
        return "assets/p_green_run.png";
    }
  }

  String get jumpAsset {
    switch (this) {
      case FormType.strength:
        return "assets/p_red_jump.png";
      case FormType.speed:
        return "assets/p_blue_jump.png";
      case FormType.skill:
        return "assets/p_green_jump.png";
    }
  }

  String get attackAsset {
    switch (this) {
      case FormType.strength:
        return "assets/p_red_atk.png";
      case FormType.speed:
        return "assets/p_blue_atk.png";
      case FormType.skill:
        return "assets/p_green_atk.png";
    }
  }

  String get defendAsset {
    switch (this) {
      case FormType.strength:
        return "assets/red_def.png";
      case FormType.speed:
        return "assets/blue_def.png";
      case FormType.skill:
        return "assets/green_def.png";
    }
  }

  String get name {
    switch (this) {
      case FormType.strength:
        return "Strength";
      case FormType.speed:
        return "Speed";
      case FormType.skill:
        return "Skill";
    }
  }

  double get speed {
    switch (this) {
      case FormType.strength:
        return 0.6;
      case FormType.speed:
        return 1.2;
      case FormType.skill:
        return 0.9;
    }
  }

  int get attackCooldownMs {
    switch (this) {
      case FormType.strength:
        return 1200;
      case FormType.speed:
        return 600;
      case FormType.skill:
        return 900;
    }
  }
}

extension EnemyTypeExt on EnemyType {
  String get idleAsset {
    switch (this) {
      case EnemyType.savage:
        return "assets/red.png";
      case EnemyType.swift:
        return "assets/blue.png";
      case EnemyType.sharp:
        return "assets/green.png";
    }
  }

  String get moveAsset {
    switch (this) {
      case EnemyType.savage:
        return "assets/red_run.png";
      case EnemyType.swift:
        return "assets/blue_run.png";
      case EnemyType.sharp:
        return "assets/green_run.png";
    }
  }

  String get attackAsset {
    switch (this) {
      case EnemyType.savage:
        return "assets/red_atk.png";
      case EnemyType.swift:
        return "assets/blue_atk.png";
      case EnemyType.sharp:
        return "assets/green_atk.png";
    }
  }

  int get maxHp {
    switch (this) {
      case EnemyType.savage:
        return 150;
      case EnemyType.swift:
        return 90;
      case EnemyType.sharp:
        return 120;
    }
  }

  double get speed {
    switch (this) {
      case EnemyType.savage:
        return 0.009;
      case EnemyType.swift:
        return 0.015;
      case EnemyType.sharp:
        return 0.012;
    }
  }

  int get attackCooldownMs {
    switch (this) {
      case EnemyType.savage:
        return 1500;
      case EnemyType.swift:
        return 900;
      case EnemyType.sharp:
        return 1200;
    }
  }
}

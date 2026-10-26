// Level data model for Slingshot Pets: what bodies exist, where, and win conditions.
// Pure Dart — no physics dependency, fully unit-testable.

/// Structural body kinds placeable in a level.
enum SmashBodyKind {
  ground, // static, unbreakable terrain
  wood, // breakable planks/crates
  glass, // fragile panes — break on light impact
  stone, // unbreakable, heavy
  cage, // breakable; holds a pet (petId required)
  tnt, // explosive barrel — breaks on light impact, blasts breakables nearby
  ball, // projectile (world-internal; never placed in level JSON)
}

/// One body placed in a level. Coordinates in meters, y-up, origin at
/// ground level under the slingshot.
class PlacedBody {
  final SmashBodyKind kind;
  final double x;
  final double y;
  final double w; // full width (boxes)
  final double h; // full height (boxes)
  final double angle; // radians, clockwise positive (screen-like)
  final String? petId; // cage only

  const PlacedBody({
    required this.kind,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.angle = 0,
    this.petId,
  });

  factory PlacedBody.fromJson(Map<String, dynamic> json) {
    final kind = SmashBodyKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => throw FormatException('unknown kind ${json['kind']}'),
    );
    return PlacedBody(
      kind: kind,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      w: (json['w'] as num).toDouble(),
      h: (json['h'] as num).toDouble(),
      angle: ((json['angle'] as num?) ?? 0).toDouble(),
      petId: json['petId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'angle': angle,
        if (petId != null) 'petId': petId,
      };
}

/// A complete level: structures + slingshot + ball budget.
class LevelDef {
  final int id;
  final int balls;
  final int par; // balls used for a 3-star rating
  final double slingX;
  final double slingY;
  final List<PlacedBody> bodies;

  const LevelDef({
    required this.id,
    required this.balls,
    required this.par,
    required this.slingX,
    required this.slingY,
    required this.bodies,
  });

  factory LevelDef.fromJson(Map<String, dynamic> json) {
    return LevelDef(
      id: (json['id'] as num).toInt(),
      balls: (json['balls'] as num).toInt(),
      par: (json['par'] as num).toInt(),
      slingX: (json['slingX'] as num).toDouble(),
      slingY: (json['slingY'] as num).toDouble(),
      bodies: (json['bodies'] as List)
          .map((e) => PlacedBody.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Number of caged pets that must be freed to win.
  int get totalPets => bodies
      .where((b) => b.kind == SmashBodyKind.cage && b.petId != null)
      .length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'balls': balls,
        'par': par,
        'slingX': slingX,
        'slingY': slingY,
        'bodies': bodies.map((b) => b.toJson()).toList(),
      };
}

import 'dart:math' as math;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

// Rig panda
class PandaPeekGame extends FlameGame {
  PandaPeekGame({required this.reduceMotion});

  // Reduced flag
  final bool reduceMotion;

  // Rig width
  static const double rigW = 700;
  // Rig height
  static const double rigH = 460;

  // Slow inspect
  bool slow = false;

  // Panda rig
  PandaRig? panda;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    camera.viewport = FixedResolutionViewport(
      resolution: Vector2(rigW, rigH),
    );
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();
    final rig = PandaRig(reduceMotion: reduceMotion);
    panda = rig;
    await world.add(rig);
    // Rig ready
    debugPrint('panda rig ready');
  }

  // Replay peek
  void replay() => panda?.replay();

  // Slow toggle
  void toggleSlow() {
    slow = !slow;
    // Slow state
    debugPrint('panda slow: $slow');
  }
}

// Panda rig
class PandaRig extends PositionComponent with HasGameReference<PandaPeekGame> {
  PandaRig({required this.reduceMotion});

  // Reduced flag
  final bool reduceMotion;

  // Canvas width
  static const double designWidth = 700;
  // Canvas height
  static const double designHeight = 460;
  // Peek length
  static const double peekSeconds = 1.6;
  // Idle length
  static const double idleSeconds = 5.0;

  // Head layer
  late SpriteComponent head;
  // Eye layer
  late SpriteComponent eyes;
  // Mouth layer
  late SpriteComponent mouth;
  // Left paw
  late SpriteComponent leftPaw;
  // Right paw
  late SpriteComponent rightPaw;

  // Eye open
  late Sprite openEyes;
  // Eye half
  late Sprite halfEyes;
  // Eye shut
  late Sprite closedEyes;
  // Joy mouth
  late Sprite happyMouth;
  // Shut mouth
  late Sprite closedMouth;
  // Left rest
  late Sprite leftDefault;
  // Left hold
  late Sprite leftGrip;
  // Right rest
  late Sprite rightDefault;
  // Right hold
  late Sprite rightGrip;

  // Show clock
  double elapsed = 0;
  // Rising flag
  bool peeking = true;

  // Left rest y
  static const double leftRestY = 347;
  // Right rest y
  static const double rightRestY = 347;

  // Unit clamp
  double clamp01(double x) => x.clamp(0.0, 1.0).toDouble();
  // Soft step
  double smooth(double x) {
    final t = clamp01(x);
    return t * t * (3 - 2 * t);
  }

  // Asset load
  Future<Sprite> asset(String name) =>
      Sprite.load('game/panda/$name.png');

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2(designWidth, designHeight);
    openEyes = await asset('eyes_open');
    halfEyes = await asset('eyes_half_blink');
    closedEyes = await asset('eyes_closed');
    happyMouth = await asset('mouth_happy');
    closedMouth = await asset('mouth_closed');
    leftDefault = await asset('left_paw_default');
    leftGrip = await asset('left_paw_grip');
    rightDefault = await asset('right_paw_default');
    rightGrip = await asset('right_paw_grip');
    // Head base
    head = SpriteComponent(
      sprite: await asset('head_base'),
      position: Vector2(36, 12),
      size: Vector2(628, 380),
      priority: 1,
    );
    // Eye pair
    eyes = SpriteComponent(
      sprite: openEyes,
      position: Vector2(249, 215),
      size: Vector2(198, 98),
      priority: 2,
    );
    // Joy mouth
    mouth = SpriteComponent(
      sprite: happyMouth,
      position: Vector2(224, 277),
      size: Vector2(264, 138),
      priority: 3,
    );
    // Left paw
    leftPaw = SpriteComponent(
      sprite: leftDefault,
      position: Vector2(51, leftRestY),
      size: Vector2(167, 106),
      priority: 4,
    );
    // Right paw
    rightPaw = SpriteComponent(
      sprite: rightDefault,
      position: Vector2(480, rightRestY),
      size: Vector2(169, 115),
      priority: 4,
    );
    await addAll([head, eyes, mouth, leftPaw, rightPaw]);
    if (reduceMotion) {
      // Settled pose
      peeking = false;
      elapsed = 1.0;
      position = Vector2.zero();
      leftPaw.sprite = leftGrip;
      rightPaw.sprite = rightGrip;
    } else {
      replay();
    }
  }

  // Replay peek
  void replay() {
    elapsed = 0;
    peeking = true;
    position = Vector2(0, 285);
    angle = 0;
    eyes.sprite = openEyes;
    mouth.sprite = happyMouth;
    leftPaw.sprite = leftDefault;
    rightPaw.sprite = rightDefault;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Frozen frame
    if (reduceMotion) return;
    final step = dt * (game.slow ? 0.25 : 1.0);
    elapsed += math.min(step, 0.05);
    if (peeking) {
      final p = clamp01(elapsed / peekSeconds);
      final t = p - 1;
      // Rise overshoot
      final rise = 1 + 2.1 * t * t * t + 1.1 * t * t;
      position.y = 285 * (1 - rise);
      // Grip stagger
      leftPaw.position.y = leftRestY - 9 * smooth((p - .45) / .25);
      rightPaw.position.y = rightRestY - 7 * smooth((p - .53) / .25);
      if (p > .54) {
        leftPaw.sprite = leftGrip;
        rightPaw.sprite = rightGrip;
      }
      angle = .018 * math.sin(p * math.pi * 2) * (1 - p);
      if (p >= 1) {
        peeking = false;
        elapsed = 0;
        position.y = 0;
        angle = 0;
      }
      return;
    }
    final t = elapsed % idleSeconds;
    final phase = 2 * math.pi * t / idleSeconds;
    // Idle breathe
    position.y = -2.4 * math.sin(phase);
    position.x = 1.3 * math.sin(phase + 0.6);
    angle = 0.004 * math.sin(phase + 0.5);
    leftPaw.position.y = 338 + 1.7 * math.sin(phase + 0.3);
    rightPaw.position.y = 340 + 1.6 * math.sin(phase + 1.2);
    // Twin blinks
    final blink1 = (t >= 1.75 && t <= 1.90);
    final blink2 = (t >= 4.32 && t <= 4.47);
    if (blink1 || blink2) {
      final start = blink1 ? 1.75 : 4.32;
      final u = (t - start) / .15;
      eyes.sprite = u < .20 || u > .80 ? halfEyes : closedEyes;
    } else {
      eyes.sprite = openEyes;
    }
    // Soft smile
    mouth.sprite = (t > 3.45 && t < 3.9) ? closedMouth : happyMouth;
  }
}

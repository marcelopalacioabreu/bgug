import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/flame.dart';
import 'package:flame/animation.dart';
import 'package:flame/position.dart';
import 'package:flame/components/component.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart' as material;

import 'math_util.dart';
import 'constants.dart';
import 'shooter.dart';

import 'background.dart' as bg;

class Background extends SpriteComponent {

  static const SPEED = 50.0;
  Position speed;

  @override
  void resize(Size size) {
    this.width = size.width;
    this.height = size.height;
    this.x = this.y = 0.0;
    this.sprite = new Sprite.fromImage(bg.generate(this.width.toInt() ~/ 4, this.height.toInt() ~/ 4));
    this.speed = new Position(SPEED, 0.0).rotate(random.nextDouble() * 2 * math.PI);
  }

  @override
  void render(Canvas c) {
    Flame.util.drawWhere(c, new Position(x - width, y - height), (c) => sprite.render(c, width, height));
    Flame.util.drawWhere(c, new Position(x, y - height), (c) => sprite.render(c, width, height));
    Flame.util.drawWhere(c, new Position(x - width, y), (c) => sprite.render(c, width, height));
    super.render(c);
  }

  @override
  void update(double dt) {
    this.x += dt * speed.x;
    this.y += dt * speed.y;

    this.x = this.x % width;
    this.y = this.y % height;
  }

  @override
  bool isHud() {
    return true;
  }
}

class UpObstacle extends SpriteComponent {
  UpObstacle(double x) : super.fromSprite(48.0, 48.0, new Sprite('obstacle.png')) {
    this.x = x;
    this.y = BAR_SIZE;
  }

  @override
  void resize(Size size) {
    width = height = tenth(size);
  }
}

class Obstacle extends UpObstacle {
  Obstacle(double x) : super(x);

  @override
  void resize(Size size) {
    super.resize(size);
    y = size.height - height - BAR_SIZE;
  }
}

class Floor extends SpriteComponent {
  Floor(double width) : super.fromSprite(1.0, BAR_SIZE, new Sprite('base.png')) {
    x = 0.0;
    this.width = width;
  }

  @override
  void resize(Size size) {
    y = size.height - BAR_SIZE;
  }
}

class Top extends SpriteComponent {
  Top(double width) : super.fromSprite(1.0, BAR_SIZE, new Sprite('base.png')) {
    x = 0.0;
    y = 0.0;
    this.width = width;
  }
}

class Gem extends SpriteComponent {
  bool collected = false;

  Gem(double x, double y) : super.fromSprite(1.0, 1.0, new Sprite('gem.png')) {
    this.x = x;
    this.y = y;
  }

  @override
  void resize(Size size) {
    this.width = this.height = 0.8 * tenth(size);
  }

  void collect() {
    this.collected = true;
  }

  @override
  bool destroy() {
    return this.collected;
  }
}

const GRAVITY_IMPULSE = 1875.0;

class Player extends PositionComponent {
  Map<String, Animation> animations;
  Point velocity = new Point(320.0, 0.0);
  Impulse jumpImpulse = new Impulse(-15000.0);
  Impulse diveImpulse = new Impulse(20000.0);
  double y0, yf, worldSize;
  String state;

  Player(double x, double y, this.worldSize) {
    this.x = x;

    animations = new Map<String, Animation>();
    animations['running'] = new Animation.sequenced('player.png', 8, textureWidth: 16.0, textureHeight: 18.0)..stepTime = 0.0375;
    animations['dead'] = new Animation.sequenced('player.png', 3, textureWidth: 16.0, textureHeight: 18.0, textureX: 16.0 * 8)..stepTime = 0.075;
    state = 'running';
  }

  @override
  void render(Canvas canvas) {
    prepareCanvas(canvas);
    animations[state].getSprite().render(canvas, width, height);
  }

  @override
  void update(double t) {
    animations[state].update(t);

    if (dead()) {
      return;
    }

    velocity.y += jumpImpulse.tick(t);
    velocity.y += diveImpulse.tick(t);
    if (falling()) {
      velocity.y += GRAVITY_IMPULSE * t;
    }

    x += velocity.x * t;
    y += velocity.y * t;
    if (y > y0) {
      y = y0;
      clearVerticalSpeed();
    } else if (y < yf) {
      y = yf;
      clearVerticalSpeed();
    }
  }

  void clearVerticalSpeed() {
    velocity.y = 0.0;
    jumpImpulse.clear();
    diveImpulse.clear();
  }

  bool dead() {
    return state == 'dead';
  }

  bool falling() {
    return y < y0;
  }

  @override
  bool destroy() {
    return x > worldSize;
  }

  @override
  void resize(Size size) {
    height = tenth(size);
    width = 48.0/54.0 * height;
    y = y0 = size.height - height - BAR_SIZE;
    yf = BAR_SIZE;
  }

  void jump(int dt) {
    if (!falling()) {
      jumpImpulse.impulse(dt.toDouble() / 2500.0);
    }
  }

  void dive() {
    if (falling()) {
      diveImpulse.impulse(0.1);
    }
  }
}

class MyGame extends BaseGame {
  static const double WORLD_SIZE = 20000.0;
  bool _running = false;
  int points = 0;
  int lastGeneratedSector = -1;

  bool isRunning() {
    return this._running;
  }

  void setRunning(bool running) {
    this._running = running;
  }

  void start() {
    add(new Background());

    add(new Top(WORLD_SIZE));
    add(new Floor(WORLD_SIZE));
    add(new Player(0.0, 0.0, WORLD_SIZE));

    add(new ShooterCane());
    add(new Shooter('up'));
    add(new Shooter('down'));
    add(new Block(0));
    add(new Block(7));

    _running = true;
  }

  generateSector(int sector) {
    double start = sector * SECTOR_LENGTH;

    for (int i = random.nextInt(4); i > 0; i--) {
      var x = start + random.nextInt(1000);
      add(random.nextBool() ? new Obstacle(x) : new UpObstacle(x));
    }
    for (int i = random.nextInt(6); i > 0; i--) {
      var x = start + random.nextInt(1000);
      add(new Gem(x, BAR_SIZE + random.nextInt(8) * tenth(size)));
    }
  }

  Player getPlayer() {
    return components.firstWhere((c) => c is Player, orElse: () => null) as Player;
  }

  Set<Shooter> getShooters() {
    return components.where((c) => c is Shooter).map((c) => c as Shooter).toSet();
  }

  void input(Position p, int dt) {
    final player = getPlayer();
    if (player != null) {
      if (player.dead()) {
        setRunning(false);
      } else {
        if (p.x > size.width / 2) {
          player.jump(dt);
        } else {
          player.dive();
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    super.render(c);
    material.TextPainter tp = Flame.util.text(points.toString(), fontFamily: 'Blox2', fontSize: 32.0, color: material.Colors.green);
    tp.paint(c, new Offset(size.width - tp.width - 8.0, size.height - tp.height - 8.0));
  }

  @override
  void update(double dt) {
    if (!isRunning()) {
      return;
    }

    Player player = getPlayer();

    while (player.x + 2 * SECTOR_LENGTH >= SECTOR_LENGTH * lastGeneratedSector) {
      lastGeneratedSector++;
      generateSector(lastGeneratedSector);
    }

    super.update(dt);

    getShooters().forEach((shooter) {
      if (shooter.shoot()) {
        add(new Bullet(size, shooter.toPosition().add(camera)));
      }
    });

    if (player != null) {
      Rect playerRect = player.toRect();
      components.forEach((c) {
        if (c is Gem) {
          if (c.toRect().overlaps(playerRect)) {
            c.collect();
            points++;
          }
        } else if (c is UpObstacle || c is Bullet) {
          PositionComponent b = c as PositionComponent;
          if (b.toRect().overlaps(playerRect)) {
            if (b is Bullet || player.velocity.x.abs() >= player.velocity.y.abs()) {
              player.x = b.x - player.width;
            } else if (player.y > size.height / 2) {
              player.y = b.y - player.height;
              player.angle = math.PI / 2;
            } else {
              player.y = b.y + b.height;
              player.angle = 3 * math.PI / 2;
            }
            player.velocity = new Point(0.0, 0.0);
            player.state = 'dead';
          }
        }
      });

      cameraFollow(player);
    } else {
      this.setRunning(false);
    }
  }

  void cameraFollow(Player c) {
    camera.x = c.x - size.width / 2 + c.width / 2;
    if (camera.x < 0.0) {
      camera.x = 0.0;
    } else if (camera.x > WORLD_SIZE - size.width) {
      camera.x = WORLD_SIZE - size.width;
    }
  }
}

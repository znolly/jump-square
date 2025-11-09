import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flame_audio/flame_audio.dart';
import 'dart:math';

void main() {
  runApp(GameWidget(game: JumpSquareGame()));
}

class JumpSquareGame extends FlameGame with TapCallbacks {
  late SpriteComponent player;
  double gravity = 600;
  double jumpSpeed = -350;
  double velocityY = 0;
  double moveX = 0;

  double playerScore = 0;
  final int platformCount = 8;
  final double platformWidth = 100;
  final double platformHeight = 20;
  final Random rand = Random();
  
  // Distancia calculada basada en la física del salto
  final double minYDistance = 60;  // Distancia mínima entre plataformas
  final double maxYDistance = 100; // Distancia máxima alcanzable con el salto

  List<SpriteComponent> platforms = [];
  bool gameOver = false;
  late TextComponent scoreText;
  late TextComponent gameOverText;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    camera.viewfinder.visibleGameSize = Vector2(400, 700);
    camera.viewfinder.position = Vector2(200, 350);

    // Inicializar y reproducir música de fondo
    try {
      FlameAudio.bgm.initialize();
      await FlameAudio.bgm.play('fondo.wav', volume: 0.5);
    } catch (e) {
      print('Error cargando audio: $e');
    }

    // Cargar sprites
    Sprite? platformSprite;
    Sprite? playerSprite;
    
    try {
      platformSprite = await loadSprite('plataforma.png');
      playerSprite = await loadSprite('personaje.png');
    } catch (e) {
      print('Error cargando sprites: $e');
    }

    // Crear plataforma inicial en el suelo
    double currentY = size.y - 100; // Comenzar desde abajo
    
    for (int i = 0; i < platformCount; i++) {
      double x = 50 + rand.nextDouble() * (size.x - platformWidth - 100);
      
      final platform = SpriteComponent(
        sprite: platformSprite,
        size: Vector2(platformWidth, platformHeight),
        position: Vector2(x, currentY),
      );
      
      // Si no hay sprite, usar color de respaldo
      if (platformSprite == null) {
        platform.paint = Paint()..color = Colors.green;
      }
      
      platforms.add(platform);
      add(platform);
      
      // Espaciado aleatorio pero dentro del rango alcanzable
      currentY -= minYDistance + rand.nextDouble() * (maxYDistance - minYDistance);
    }

    // Jugador siempre empieza sobre la PRIMERA plataforma (la más baja)
    player = SpriteComponent(
      sprite: playerSprite,
      size: Vector2(40, 40),
      position: Vector2(
        platforms[0].x + platformWidth / 2 - 20, // Centrado en la plataforma
        platforms[0].y - 40
      ),
    );
    
    // Si no hay sprite, usar color de respaldo
    if (playerSprite == null) {
      player.paint = Paint()..color = Colors.red;
    }
    
    add(player);

    // Texto de puntuación
    scoreText = TextComponent(
      text: "Score: 0",
      position: Vector2(10, 10),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      priority: 10,
    );
    add(scoreText);

    // Texto Game Over
    gameOverText = TextComponent(
      text: "GAME OVER\nTap to Restart",
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.red,
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
      priority: 20,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameOver) return;

    // Gravedad y movimiento
    velocityY += gravity * dt;
    player.y += velocityY * dt;
    player.x += moveX * dt;

    // Bordes horizontales
    if (player.x < 0) player.x = 0;
    if (player.x + player.width > size.x) player.x = size.x - player.width;

    // Colisión y rebote en plataformas
    for (final platform in platforms) {
      // Solo rebotar si está cayendo (velocityY > 0) y el pie del jugador toca la plataforma
      if (velocityY > 0 &&
          player.y + player.height >= platform.y &&
          player.y + player.height <= platform.y + platformHeight + 10 &&
          player.x + player.width > platform.x &&
          player.x < platform.x + platformWidth) {
        velocityY = jumpSpeed;
        player.y = platform.y - player.height; // Ajustar posición exacta
      }
    }

    // Scroll vertical infinito cuando el jugador sube
    if (player.y < size.y / 3) {
      double dy = (size.y / 3 - player.y);
      player.y = size.y / 3;

      for (final platform in platforms) {
        platform.y += dy;
        
        // Regenerar plataformas que salen por abajo
        if (platform.y > size.y + 50) {
          // Encontrar la plataforma más alta actual
          double highestY = platforms
              .where((p) => p != platform)
              .map((p) => p.y)
              .reduce((a, b) => a < b ? a : b);
          
          // Nueva plataforma arriba de la más alta
          platform.y = highestY - minYDistance - rand.nextDouble() * (maxYDistance - minYDistance);
          platform.x = 50 + rand.nextDouble() * (size.x - platformWidth - 100);
        }
      }

      playerScore += dy;
      scoreText.text = "Score: ${playerScore.toInt()}";
    }

    // Game Over si cae por debajo de la pantalla
    if (player.y > size.y + 50) {
      gameOver = true;
      add(gameOverText);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (gameOver) {
      restartGame();
      return;
    }

    final touchX = event.localPosition.x;
    if (touchX < size.x / 2) {
      moveX = -150;
    } else {
      moveX = 150;
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    moveX = 0;
  }

  void restartGame() {
    // Reset plataformas desde abajo
    double currentY = size.y - 100;
    for (final platform in platforms) {
      platform.x = 50 + rand.nextDouble() * (size.x - platformWidth - 100);
      platform.y = currentY;
      currentY -= minYDistance + rand.nextDouble() * (maxYDistance - minYDistance);
    }

    // Reset jugador sobre la primera plataforma
    player.position = Vector2(
      platforms[0].x + platformWidth / 2 - 20,
      platforms[0].y - 40
    );
    velocityY = 0;
    moveX = 0;

    // Reset score
    playerScore = 0;
    scoreText.text = "Score: 0";

    // Ocultar Game Over
    remove(gameOverText);
    gameOver = false;
  }

  @override
  void onRemove() {
    FlameAudio.bgm.dispose();
    super.onRemove();
  }
}
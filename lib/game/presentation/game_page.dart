import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Game page
class GamePage extends StatelessWidget {
  const GamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fulgens - Game'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_esports_outlined, size: 48, color: Color(0xFFFF7A45)),
            SizedBox(height: 12),
            Text('Game - Blank'),
            SizedBox(height: 4),
            Text(
              'Game drawer — Rive/Flame goes here',
              style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

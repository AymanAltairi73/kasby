import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:confetti/confetti.dart';

class ConfettiService extends GetxService {
  static ConfettiService get to => Get.find();

  late ConfettiController _controller;
  ConfettiController get controller => _controller;

  @override
  void onInit() {
    super.onInit();
    _controller = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void onClose() {
    _controller.dispose();
    super.onClose();
  }

  void celebrate() {
    _controller.play();
  }

  /// Global Confetti Widget that can be placed in a Stack at the root of the app.
  Widget buildConfetti() {
    return Align(
      alignment: Alignment.center,
      child: ConfettiWidget(
        confettiController: _controller,
        blastDirection: -pi / 2, // Up
        emissionFrequency: 0.05,
        numberOfParticles: 20,
        gravity: 0.05,
        shouldLoop: false,
        colors: const [
          Colors.green,
          Colors.blue,
          Colors.pink,
          Colors.orange,
          Colors.purple,
          Color(0xFFD4AF37), // Gold
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class SplashProvider with ChangeNotifier {
  late AnimationController logoController;
  late AnimationController buttonController;

  late Animation<double> logoAnimation;
  late Animation<double> buttonFadeAnimation;

  void initControllers(TickerProvider vsync) {
    logoController = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 1),
    );

    buttonController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1000),
    );

    logoAnimation = Tween<double>(
      begin: 105.0,
      end: -50.0,
    ).animate(CurvedAnimation(
      parent: logoController,
      curve: Curves.easeInOut,
    ));

    buttonFadeAnimation = CurvedAnimation(
      parent: buttonController,
      curve: Curves.easeIn,
    );
  }

  void startAnimations() {
    Future.delayed(const Duration(seconds: 2), () {
      logoController.forward().whenComplete(() {
        buttonController.forward();
        notifyListeners();
      });
    });
  }

  void disposeControllers() {
    logoController.dispose();
    buttonController.dispose();
  }
}

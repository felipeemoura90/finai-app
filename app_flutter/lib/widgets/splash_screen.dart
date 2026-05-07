import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_config.dart';

class FinAiSplashScreen extends StatefulWidget {
  const FinAiSplashScreen({super.key});

  @override
  State<FinAiSplashScreen> createState() => _FinAiSplashScreenState();
}

class _FinAiSplashScreenState extends State<FinAiSplashScreen> with TickerProviderStateMixin {
  late AnimationController _blobController;
  late AnimationController _floatController;

  final List<FloatingItem> _floatingItems = [];

  @override
  void initState() {
    super.initState();
    
    // Animação do mesh gradient (bolhas de fundo)
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // Animação dos ícones flutuantes
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _initializeFloatingItems();
  }

  void _initializeFloatingItems() {
    final random = math.Random();
    final icons = [
      Icons.shopping_cart,
      Icons.bolt,
      Icons.medical_services,
      Icons.school,
      Icons.restaurant,
      Icons.flight,
      Icons.home,
      Icons.directions_car,
      Icons.account_balance,
      Icons.coffee,
    ];

    for (int i = 0; i < 20; i++) {
      _floatingItems.add(
        FloatingItem(
          icon: icons[random.nextInt(icons.length)],
          xPos: random.nextDouble(), // 0.0 to 1.0 (horizontal)
          speed: 0.1 + random.nextDouble() * 0.4, // Speed of floating
          size: 16.0 + random.nextDouble() * 24.0, // Size of icon
          opacity: 0.05 + random.nextDouble() * 0.15, // Subtle opacity
          initialYPos: random.nextDouble(), // Start distributed vertically
        ),
      );
    }
  }

  @override
  void dispose() {
    _blobController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Mesh Gradient (Animated Blobs)
          AnimatedBuilder(
            animation: _blobController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: size.height * 0.2 + math.sin(_blobController.value * math.pi * 2) * 50,
                    left: size.width * 0.2 + math.cos(_blobController.value * math.pi * 2) * 50,
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.emeraldColor.withOpacity(0.35),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: size.height * 0.2 + math.cos(_blobController.value * math.pi * 2) * 50,
                    right: size.width * 0.1 + math.sin(_blobController.value * math.pi * 2) * 50,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.indigoColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 2. Heavy Blur for the Mesh Gradient effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox(),
            ),
          ),

          // 3. Floating Categories
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Stack(
                children: _floatingItems.map((item) {
                  // Y flows from bottom to top over time
                  double yPos = item.initialYPos - (_floatController.value * item.speed);
                  // Wrap around when it goes off screen
                  if (yPos < -0.2) {
                    yPos += 1.4;
                  } else if (yPos > 1.2) {
                    yPos -= 1.4;
                  }

                  return Positioned(
                    left: item.xPos * size.width,
                    top: yPos * size.height,
                    child: Opacity(
                      opacity: item.opacity,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Icon(
                          item.icon,
                          color: AppColors.textPrimary,
                          size: item.size,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // 4. Center Glassmorphism Panel
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  width: 280,
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícone central brilhante
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.emeraldColor.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emeraldColor.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          size: 56,
                          color: AppColors.emeraldColor,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      const Text(
                        'FinAI',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Inteligência Financeira',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      // Loading indicator elegante
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emeraldColor),
                          backgroundColor: AppColors.emeraldColor.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FloatingItem {
  final IconData icon;
  final double xPos;
  final double initialYPos;
  final double speed;
  final double size;
  final double opacity;

  FloatingItem({
    required this.icon,
    required this.xPos,
    required this.initialYPos,
    required this.speed,
    required this.size,
    required this.opacity,
  });
}

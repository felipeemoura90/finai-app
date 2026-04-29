import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../core/theme/app_colors.dart'; // Adicionamos a importação das cores

class AuthGuard extends StatelessWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.background, // Fundo escuro
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.emeraldColor, // Bolinha giratória verde
              ),
            ),
          );
        }

        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        return child;
      },
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_config.dart'; //[cite: 1]

class FinAiSplashScreen extends StatefulWidget {
  const FinAiSplashScreen({super.key});

  @override
  State<FinAiSplashScreen> createState() => _FinAiSplashScreenState();
}

class _FinAiSplashScreenState extends State<FinAiSplashScreen> {
  int _currentIndex = 0;
  bool _isClean = false;

  // Exemplos baseados no seu arquivo regras.db[cite: 19]
  final List<Map<String, String>> _mockTransactions = [
    {
      'raw': 'SUPERMERCADO GERACAO',
      'clean': 'Supermercado Geração',
      'icon': 'shopping_cart',
    },
    {
      'raw': 'CELESC  CONTA LUZ',
      'clean': 'Energia Elétrica (Celesc)',
      'icon': 'bolt',
    },
    {
      'raw': 'HAPVIDA ASSISTENCIA',
      'clean': 'Plano de Saúde',
      'icon': 'medical_services',
    },
    {
      'raw': 'SOCIESC MENSALIDADE',
      'clean': 'Faculdade (UniSociesc)',
      'icon': 'school',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    // Ciclo de animação: mostra o texto bruto, brilha, limpa o texto, pula para o próximo
    Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_isClean) {
          _isClean = false;
          _currentIndex = (_currentIndex + 1) % _mockTransactions.length;
        } else {
          _isClean = true;
        }
      });
    });
  }

  IconData _getIcon(String name) {
    // Mapeamento simplificado para a splash[cite: 18]
    switch (name) {
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'bolt':
        return Icons.bolt;
      case 'medical_services':
        return Icons.medical_services;
      case 'school':
        return Icons.school;
      default:
        return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _mockTransactions[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.background, //[cite: 1]
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo Central[cite: 6]
            const Icon(
              Icons.account_balance_wallet,
              size: 80,
              color: AppColors.primary, //[cite: 1]
            ),
            const SizedBox(height: 48),

            // Área de Texto "Processando"
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Container(
                key: ValueKey('$_currentIndex-$_isClean'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgCard, //[cite: 1]
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isClean
                        ? AppColors.emeraldColor.withOpacity(0.5)
                        : AppColors.slate800, //[cite: 1]
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isClean
                          ? _getIcon(current['icon']!)
                          : Icons.hourglass_empty,
                      color: _isClean
                          ? AppColors.emeraldColor
                          : AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _isClean ? current['clean']! : current['raw']!,
                      style: TextStyle(
                        color: _isClean
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: _isClean
                            ? FontWeight.bold
                            : FontWeight.w400,
                        fontFamily:
                            'monospace', // Dá um ar de processamento de dados
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.emeraldColor, //[cite: 1]
            ),
          ],
        ),
      ),
    );
  }
}

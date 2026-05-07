import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_config.dart';
import '../services/api_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onSkip;
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    required this.onSkip,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;
  String _statusMessage = '';
  String? _errorMessage;

  late AnimationController _pulseController;
  late AnimationController _blobController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _blobController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Extratos Bancários',
        extensions: <String>['csv', 'txt', 'ofx'],
      );

      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );

      if (file == null) return;

      final fileBytes = await file.readAsBytes();

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Lendo o arquivo...';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _statusMessage = 'A IA está analisando suas transações...';
      });

      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken ?? '';

      final success = await _apiService.uploadFile(
        fileBytes,
        file.name,
        token,
      );

      if (success) {
        setState(() {
          _statusMessage = 'Transações importadas com sucesso!';
        });
        await Future.delayed(const Duration(seconds: 1));
        widget.onComplete();
      } else {
        setState(() {
          _isProcessing = false;
          _errorMessage =
              'Erro ao processar o arquivo. Verifique o formato e tente novamente.';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Erro inesperado: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Mesh gradient background
          AnimatedBuilder(
            animation: _blobController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: size.height * 0.15 +
                        math.sin(_blobController.value * math.pi * 2) * 40,
                    right: size.width * 0.1 +
                        math.cos(_blobController.value * math.pi * 2) * 40,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.emeraldColor.withOpacity(0.25),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: size.height * 0.15 +
                        math.cos(_blobController.value * math.pi * 2) * 40,
                    left: size.width * 0.05 +
                        math.sin(_blobController.value * math.pi * 2) * 40,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.indigoColor.withOpacity(0.2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Heavy blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: const SizedBox(),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _isProcessing
                    ? _buildProcessingView()
                    : _buildWelcomeView(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeView() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 28),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.emeraldColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.emeraldColor.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emeraldColor.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: AppColors.emeraldColor,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Bem-vindo ao FinAI!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Importe seu extrato bancário e deixe nossa IA organizar suas finanças automaticamente.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Supported formats
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.slate800.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.textMuted, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Formatos: CSV, TXT e OFX',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Upload button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickAndUploadFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text(
                    'Importar meu extrato',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Skip button
              TextButton(
                onPressed: widget.onSkip,
                child: const Text(
                  'Pular por agora →',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingView() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 28),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.4),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated pulsing icon
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + _pulseController.value * 0.15;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldColor
                            .withOpacity(0.08 + _pulseController.value * 0.08),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emeraldColor.withOpacity(
                                0.1 + _pulseController.value * 0.15),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.psychology,
                        size: 56,
                        color: AppColors.emeraldColor,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _statusMessage,
                  key: ValueKey(_statusMessage),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Isso pode levar alguns segundos...',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.emeraldColor),
                  backgroundColor: AppColors.emeraldColor.withOpacity(0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

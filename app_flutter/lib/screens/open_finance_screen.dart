import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_pluggy_connect/flutter_pluggy_connect.dart';
import '../core/app_config.dart';
import '../services/api_service.dart';

class OpenFinanceScreen extends StatefulWidget {
  const OpenFinanceScreen({super.key});

  @override
  State<OpenFinanceScreen> createState() => _OpenFinanceScreenState();
}

class _OpenFinanceScreenState extends State<OpenFinanceScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _openPluggyWidget() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken ?? '';

      // Busca o connect token do backend
      final result = await _apiService.getPluggyConnectToken(token);
      if (result == null) {
        setState(() {
          _errorMessage = 'Não foi possível iniciar a conexão. Verifique sua API.';
          _isLoading = false;
        });
        return;
      }

      setState(() => _isLoading = false);

      if (!mounted) return;

      // Abre o Pluggy Connect Widget
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PluggyConnect(
            connectToken: result,
            onSuccess: (itemData) async {
              Navigator.pop(context);
              final itemId = itemData['item']?['id'];
              if (itemId != null) {
                await _syncAccount(itemId, token);
              }
            },
            onError: (error) {
              Navigator.pop(context);
              setState(() {
                _errorMessage = 'Erro ao conectar: $error';
              });
            },
            onClose: () {
              Navigator.pop(context);
            },
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro inesperado: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _syncAccount(String itemId, String token) async {
    setState(() {
      _isSyncing = true;
      _successMessage = null;
      _errorMessage = null;
    });

    try {
      final ok = await _apiService.syncPluggyAccount(itemId, token);
      setState(() {
        _isSyncing = false;
        if (ok) {
          _successMessage =
              'Banco conectado! Suas transações estão sendo importadas em segundo plano.';
        } else {
          _errorMessage = 'Conexão feita, mas falha ao iniciar sincronização.';
        }
      });
    } catch (e) {
      setState(() {
        _isSyncing = false;
        _errorMessage = 'Erro ao sincronizar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.bgSidebar,
        title: const Text(
          'Open Finance',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.indigoColor.withOpacity(0.2),
                      AppColors.emeraldColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.indigoColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.indigoColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        size: 40,
                        color: AppColors.indigoColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Conecte seu banco',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pelo Open Finance, suas transações são importadas automaticamente e categorizadas pela IA — sem precisar enviar extratos manualmente.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Features list
              _buildFeatureItem(
                Icons.sync,
                'Sincronização automática',
                'Transações importadas direto do banco',
                AppColors.emeraldColor,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                Icons.psychology,
                'Categorização por IA',
                'Cada transação é analisada e categorizada',
                AppColors.indigoColor,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                Icons.security,
                'Seguro e regulamentado',
                'Conexão via Open Finance Brasil (BACEN)',
                Colors.amber,
              ),

              const SizedBox(height: 32),

              // Messages
              if (_successMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.emeraldColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.emeraldColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                              color: AppColors.emeraldColor, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

              // Main button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isLoading || _isSyncing)
                      ? null
                      : _openPluggyWidget,
                  icon: (_isLoading || _isSyncing)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.link),
                  label: Text(
                    _isSyncing
                        ? 'Sincronizando...'
                        : _isLoading
                            ? 'Conectando...'
                            : 'Conectar meu banco',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.indigoColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.indigoColor.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
      IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate800),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'core/app_config.dart';
import 'providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'FinAI',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gerencie suas finanças com inteligência artificial',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          _handleGoogleSignIn(context, authProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/google_logo.png',
                              height: 28,
                              width: 28,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Continuar com Google',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (authProvider.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        authProvider.errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ao continuar, você concorda com nossos Termos de Uso e Política de Privacidade.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleGoogleSignIn(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    try {
      await authProvider.signInWithGoogle();
      if (!context.mounted) return;
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Erro ao fazer login')));
    }
  }
}

class Tela1Dashboard extends StatelessWidget {
  final String mesReferencia;
  final double metaMensal;

  const Tela1Dashboard({
    super.key,
    required this.mesReferencia,
    required this.metaMensal,
  });

  Future<Map<String, dynamic>> fetchDashboard() async {
    final url = Uri.parse(
      '$apiBaseUrl/dashboard?mes=$mesReferencia&meta_mensal=$metaMensal',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Falha ao carregar dados');
    }
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatarMoeda(dynamic valor) {
    final numeroSeguro = _safeDouble(valor);
    return numeroSeguro.toStringAsFixed(2);
  }

  Color _getColorForCategory(String nome) {
    switch (nome.toLowerCase()) {
      case 'alimentação':
      case 'alimentos':
        return Colors.amber;
      case 'transporte':
        return AppColors.primary;
      case 'investimento':
        return AppColors.emeraldColor;
      case 'saúde':
        return Colors.redAccent;
      case 'moradia':
      case 'contas fixas':
        return Colors.blueAccent;
      default:
        return AppColors.indigoColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 800;

    return FutureBuilder<Map<String, dynamic>>(
      future: fetchDashboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.emeraldColor),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Servidor Python Offline ou Erro de Dados.',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final double ganhos = _safeDouble(data['ganhos']);
        final double gastos = _safeDouble(data['gastos']);
        final double saldo = _safeDouble(data['saldo']);
        final double meta = _safeDouble(data['meta']);
        final double projecaoIa = _safeDouble(data['projecao_ia']);
        final String insight =
            data['insight_ia'] ?? 'Nenhum insight disponível.';
        final List categorias = data['categorias'] ?? [];
        final double wReal = meta > 0 ? (gastos / meta).clamp(0.0, 1.0) : 0.0;
        final double wProj = meta > 0
            ? (projecaoIa / meta).clamp(0.0, 1.0)
            : 0.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 32.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHealthWidget(
                    context,
                    ganhos,
                    gastos,
                    saldo,
                    meta,
                    projecaoIa,
                    wReal,
                    wProj,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.emeraldColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: AppColors.emeraldColor,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            insight,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Distribuição de Gastos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (categorias.isEmpty)
                    const Text(
                      'Nenhum gasto registrado neste mês.',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.slate800),
                      ),
                      child: Column(
                        children: categorias.map<Widget>((cat) {
                          final double valorCat = _safeDouble(cat['valor']);
                          final double porcentagem = gastos > 0
                              ? (valorCat / gastos).clamp(0.0, 1.0)
                              : 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          cat['nome'].toString(),
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(${(porcentagem * 100).toStringAsFixed(1)}%)',
                                          style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'R\$ ${_formatarMoeda(valorCat)}',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Stack(
                                  children: [
                                    Container(
                                      height: 8,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppColors.slate800,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: porcentagem,
                                      child: Container(
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: _getColorForCategory(
                                            cat['nome'].toString(),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHealthWidget(
    BuildContext context,
    double ganhos,
    double gastos,
    double saldo,
    double meta,
    double projecao,
    double wReal,
    double wProj,
  ) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.slate800),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo disponível',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'R\$ ${saldo.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.trending_up,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Meta ativa',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniCard('Ganhos', ganhos, AppColors.emeraldColor),
                  _buildMiniCard('Gastos', gastos, Colors.orangeAccent),
                  _buildMiniCard('Meta', meta, AppColors.indigoColor),
                ],
              ),
              const SizedBox(height: 32),
              _buildProgressRow(
                'Projeção IA',
                projecao,
                wProj,
                AppColors.primary,
              ),
              const SizedBox(height: 16),
              _buildProgressRow('Real', gastos, wReal, AppColors.emeraldColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCard(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.slate800,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              'R\$ ${_formatarMoeda(amount)}',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(
    String label,
    double amount,
    double progress,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'R\$ ${_formatarMoeda(amount)}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress,
          minHeight: 10,
          backgroundColor: AppColors.slate800,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}

class Tela2Feed extends StatefulWidget {
  final String mesReferencia;

  const Tela2Feed({super.key, required this.mesReferencia});

  @override
  State<Tela2Feed> createState() => _Tela2FeedState();
}

class _Tela2FeedState extends State<Tela2Feed> {
  Future<List<dynamic>> fetchFeed() async {
    final url = Uri.parse(
      '$apiBaseUrl/feed?mes=${widget.mesReferencia}',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'] ?? [];
    } else {
      throw Exception('Falha ao carregar dados do Feed');
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'bolt':
        return Icons.bolt;
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'local_cafe':
        return Icons.local_cafe;
      case 'bakery_dining':
        return Icons.bakery_dining;
      case 'apartment':
        return Icons.apartment;
      case 'account_balance':
        return Icons.account_balance;
      case 'local_gas_station':
        return Icons.local_gas_station;
      case 'school':
        return Icons.school;
      case 'medical_services':
        return Icons.medical_services;
      case 'local_pharmacy':
        return Icons.local_pharmacy;
      case 'compare_arrows':
        return Icons.compare_arrows;
      case 'payment':
        return Icons.payment;
      case 'wifi':
        return Icons.wifi;
      default:
        return Icons.receipt;
    }
  }

  void _mostrarDialogoRegra(BuildContext context, Map<String, dynamic> item) {
    final keywordCtrl = TextEditingController(text: item['raw']);
    final nameCtrl = TextEditingController(text: item['name']);
    String categoriaSelecionada = item['categoria'] ?? 'Outros';
    String iconeSelecionado = item['icon'] ?? 'help_outline';

    final categorias = [
      'Mercado',
      'Alimentação',
      'Contas Fixas',
      'Saúde',
      'Transporte',
      'Educação',
      'Transferência',
      'Serviços',
      'Outros',
    ];
    final icones = [
      'shopping_cart',
      'restaurant',
      'local_cafe',
      'bolt',
      'apartment',
      'medical_services',
      'local_pharmacy',
      'payment',
      'help_outline',
    ];

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.bgCard,
          title: const Text(
            'Editar Transação',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keywordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Raw',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nome',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categoriaSelecionada,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  items: categorias
                      .map(
                        (categoria) => DropdownMenuItem(
                          value: categoria,
                          child: Text(categoria),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      categoriaSelecionada = value;
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: iconeSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Ícone',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  items: icones
                      .map(
                        (icone) =>
                            DropdownMenuItem(value: icone, child: Text(icone)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      iconeSelecionado = value;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Salvar',
                style: TextStyle(color: AppColors.emeraldColor),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 800;

    return FutureBuilder<List<dynamic>>(
      future: fetchFeed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.emeraldColor),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Erro ao carregar transações.',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final dados = snapshot.data ?? [];
        if (dados.isEmpty) {
          return const Center(
            child: Text(
              'Nenhuma transação neste mês.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView.builder(
              padding: EdgeInsets.all(isSmallScreen ? 16.0 : 32.0),
              itemCount: dados.length,
              itemBuilder: (context, index) {
                final item = dados[index];
                final String nome = item['name'] ?? 'Desconhecido';
                final String raw = item['raw'] ?? '';
                final String valor = item['value'] ?? 'R\$ 0,00';
                final String iconStr = item['icon'] ?? 'receipt';
                final String trust = item['trust'] ?? 'low';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () => _mostrarDialogoRegra(context, item),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.slate800),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.slate800,
                            child: Icon(
                              _getIconData(iconStr),
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nome,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Raw: $raw',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                valor,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: trust == 'high'
                                      ? AppColors.emeraldColor.withOpacity(0.1)
                                      : trust == 'ai'
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      trust == 'high'
                                          ? Icons.check_circle
                                          : trust == 'ai'
                                          ? Icons.smart_toy
                                          : Icons.warning,
                                      color: trust == 'high'
                                          ? AppColors.emeraldColor
                                          : trust == 'ai'
                                          ? Colors.blue
                                          : Colors.amber,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      trust == 'high'
                                          ? 'Manual'
                                          : trust == 'ai'
                                          ? 'IA'
                                          : 'Validar?',
                                      style: TextStyle(
                                        color: trust == 'high'
                                            ? AppColors.emeraldColor
                                            : trust == 'ai'
                                            ? Colors.blue
                                            : Colors.amber,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class Tela3Calendar extends StatelessWidget {
  final String mesReferencia;

  const Tela3Calendar({super.key, required this.mesReferencia});

  Future<List<dynamic>> fetchFluxo() async {
    final url = Uri.parse(
      '$apiBaseUrl/fluxo?mes=$mesReferencia',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Falha ao carregar fluxo');
    }
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: fetchFluxo(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.emeraldColor),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Erro ao carregar movimentação financeira.',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        final dados = snapshot.data ?? [];
        if (dados.isEmpty) {
          return const Center(
            child: Text(
              'Sem dados para este mês.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        final parts = mesReferencia.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final firstDay = DateTime(year, month, 1);
        final startOffset = firstDay.weekday == 7 ? 0 : firstDay.weekday;
        double maxGain = 0;
        double maxLoss = 0;

        for (var item in dados) {
          final mov = _safeDouble(item['movimento']);
          if (mov > maxGain) maxGain = mov;
          if (mov < 0 && mov.abs() > maxLoss) maxLoss = mov.abs();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Movimentação Financeira Mensal',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Visualize a intensidade das suas movimentações financeiras. Toque em cada dia para detalhes.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
                        .map(
                          (day) => Expanded(
                            child: Center(
                              child: Text(
                                day,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: startOffset + dados.length,
                    itemBuilder: (context, index) {
                      if (index < startOffset) {
                        return const SizedBox.shrink();
                      }

                      final dayIndex = index - startOffset;
                      final diaData = dados[dayIndex];
                      final diaNum = diaData['dia'];
                      final mov = _safeDouble(diaData['movimento']);
                      final saldo = _safeDouble(diaData['valor']);
                      final transacoes = (diaData['transacoes'] as List?) ?? [];

                      return _buildHeatmapCell(
                        context,
                        diaNum,
                        mov,
                        saldo,
                        maxGain,
                        maxLoss,
                        transacoes,
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  _buildLegend(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeatmapCell(
    BuildContext context,
    int dia,
    double mov,
    double saldo,
    double maxGain,
    double maxLoss,
    List transacoes,
  ) {
    Color cellColor;
    var textColor = AppColors.textPrimary;

    if (mov == 0) {
      cellColor = AppColors.slate800.withOpacity(0.3);
      textColor = AppColors.textMuted;
    } else if (mov > 0) {
      final intensity = maxGain > 0 ? (mov / maxGain).clamp(0.2, 1.0) : 0.5;
      cellColor = AppColors.emeraldColor.withOpacity(intensity);
      if (intensity > 0.6) textColor = Colors.black87;
    } else {
      final intensity = maxLoss > 0
          ? (mov.abs() / maxLoss).clamp(0.2, 1.0)
          : 0.5;
      cellColor = Colors.redAccent.withOpacity(intensity);
    }

    return InkWell(
      onTap: () => _showDayDetails(context, dia, saldo, transacoes),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.slate800.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            dia.toString(),
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _showDayDetails(
    BuildContext context,
    int dia,
    double saldo,
    List transacoes,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.5;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.only(
              top: 24.0,
              left: 24.0,
              right: 24.0,
              bottom: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo: R\$ ${saldo.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: transacoes.length,
                    itemBuilder: (context, index) {
                      final transacao = transacoes[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                transacao['descricao']?.toString() ?? 'Evento',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              'R\$ ${_safeDouble(transacao['valor']).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Legenda',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildLegendDot(Colors.redAccent, 'Perda'),
            const SizedBox(width: 12),
            _buildLegendDot(AppColors.emeraldColor, 'Ganho'),
            const SizedBox(width: 12),
            _buildLegendDot(
              AppColors.slate800.withOpacity(0.3),
              'Sem movimentação',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class Tela4Settings extends StatefulWidget {
  const Tela4Settings({super.key});

  @override
  State<Tela4Settings> createState() => _Tela4SettingsState();
}

class _Tela4SettingsState extends State<Tela4Settings> {
  bool _autoAdjust = true;

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16.0 : 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Parâmetros de Controle',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Defina os limites (set-points) para a malha de controle do seu orçamento.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.slate800),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.indigoColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.indigoColor.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 8,
                                    children: const [
                                      Icon(
                                        Icons.auto_awesome,
                                        color: AppColors.indigoColor,
                                        size: 16,
                                      ),
                                      Text(
                                        'Auto-Ajuste (IA)',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Permite sugerir ajustes baseados na inflação via Python.',
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Switch(
                              value: _autoAdjust,
                              activeThumbColor: AppColors.textPrimary,
                              activeTrackColor: AppColors.indigoColor,
                              onChanged: (val) {
                                setState(() {
                                  _autoAdjust = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildSliderItem(
                        'Fixo (Contas & Moradia)',
                        0.5,
                        'R\$ 2.600',
                        '50%',
                        Colors.blue,
                      ),
                      const SizedBox(height: 24),
                      _buildSliderItem(
                        'Variável (Lazer & Lanches)',
                        0.3,
                        'R\$ 1.560',
                        '30%',
                        Colors.amber,
                      ),
                      const SizedBox(height: 24),
                      _buildSliderItem(
                        'Investimento (Aporte)',
                        0.2,
                        'R\$ 1.040',
                        '20%',
                        AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderItem(
    String label,
    double value,
    String amount,
    String percentage,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                children: [
                  TextSpan(
                    text: '$amount ',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  TextSpan(
                    text: '($percentage)',
                    style: const TextStyle(
                      color: AppColors.slate800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value,
          backgroundColor: AppColors.slate800,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

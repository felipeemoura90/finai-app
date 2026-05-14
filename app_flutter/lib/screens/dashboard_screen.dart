import 'package:flutter/material.dart';
import '../core/app_config.dart';
import '../services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_pluggy_connect/flutter_pluggy_connect.dart';

class Tela1Dashboard extends StatefulWidget {
  final String mesReferencia;
  final double metaMensal;

  const Tela1Dashboard({
    super.key,
    required this.mesReferencia,
    required this.metaMensal,
  });

  @override
  State<Tela1Dashboard> createState() => _Tela1DashboardState();
}

class _Tela1DashboardState extends State<Tela1Dashboard> {
  final ApiService _apiService = ApiService(); // Instância do serviço
  late Future<Map<String, dynamic>> _dashboardFuture;

  // --- NOVO: Variável de controle do botão da Pluggy ---
  bool _isConnectingBank = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant Tela1Dashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mesReferencia != widget.mesReferencia ||
        oldWidget.metaMensal != widget.metaMensal) {
      _loadData();
    }
  }

  void _loadData() {
    // Busca o token da sessão atual do Supabase
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? '';

    setState(() {
      // Passa o token para a função do serviço
      _dashboardFuture = _apiService.getDashboard(
        widget.mesReferencia,
        widget.metaMensal,
        token,
      );
    });
  }

  // --- NOVO: Função que chama a API e abre a tela nativa da Pluggy ---
  Future<void> _conectarBanco() async {
    setState(() => _isConnectingBank = true);

    try {
      // 1. Pede o passe (token) para a sua API em Python
      final token = await _apiService.getPluggyConnectToken();

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Erro ao iniciar conexão com banco. Verifique sua API.',
              ),
            ),
          );
        }
        setState(() => _isConnectingBank = false);
        return;
      }

      // 2. Cria a tela nativa da Pluggy
      final pluggyConnect = PluggyConnect(
        connectToken: token,
        includeSandbox: true, // Em produção, mude para false
        onSuccess: (successData) async {
          // O usuário logou! Pegamos o ID da conexão
          final item = successData['item'];
          final itemId = item['id'];

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Banco conectado! Sincronizando dados no servidor...',
                ),
              ),
            );
          }

          // 3. Manda o item_id para o Python processar e salvar
          await _apiService.syncPluggyAccount(itemId);

          setState(() => _isConnectingBank = false);
        },
        onError: (errorData) {
          print('Erro no fluxo da Pluggy: $errorData');
          setState(() => _isConnectingBank = false);
        },
        onClose: () {
          setState(() => _isConnectingBank = false);
        },
      );

      // 4. Exibe o widget na tela
      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (context) => pluggyConnect));
      }
    } catch (e) {
      print('Erro inesperado: $e');
      setState(() => _isConnectingBank = false);
    }
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatarMoeda(dynamic valor) {
    return _safeDouble(valor).toStringAsFixed(2);
  }

  Color _getColorForCategory(String nome) {
    switch (nome.toLowerCase()) {
      case 'alimentação':
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
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.emeraldColor),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Erro ao carregar dados.',
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
                    ganhos,
                    gastos,
                    saldo,
                    meta,
                    projecaoIa,
                    wReal,
                    wProj,
                  ),
                  const SizedBox(height: 24),

                  // --- NOVO: Botão estilizado para Conectar o Banco ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isConnectingBank ? null : _conectarBanco,
                      icon: _isConnectingBank
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.account_balance,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isConnectingBank
                            ? 'Iniciando Conexão...'
                            : 'Conectar Banco Automaticamente',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors
                            .emeraldColor, // Usando a cor de sucesso do seu app
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ----------------------------------------------------
                  _buildInsightCard(insight),
                  const SizedBox(height: 32),
                  const Text(
                    'Distribuição de Gastos',
                    style: TextStyle(
                      fontSize: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCategoriesList(categorias, gastos),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Widgets auxiliares mantidos para organização...
  Widget _buildInsightCard(String insight) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.emeraldColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emeraldColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.emeraldColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              insight,
              style: const TextStyle(color: AppColors.textPrimary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList(List categorias, double totalGastos) {
    if (categorias.isEmpty) {
      return const Text(
        'Sem gastos registrados.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate800),
      ),
      child: Column(
        children: categorias.map<Widget>((cat) {
          final double valorCat = _safeDouble(cat['valor']);
          final double porcentagem = totalGastos > 0
              ? (valorCat / totalGastos)
              : 0.0;
          return _buildCategoryItem(cat['nome'], valorCat, porcentagem);
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryItem(String nome, double valor, double porcentagem) {
    final String pctStr = '${(porcentagem * 100).toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nome, style: const TextStyle(color: AppColors.textPrimary)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${_formatarMoeda(valor)}',
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pctStr,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: porcentagem,
            backgroundColor: AppColors.slate800,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getColorForCategory(nome),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthWidget(
    double ganhos,
    double gastos,
    double saldo,
    double meta,
    double projecao,
    double wReal,
    double wProj,
  ) {
    return Container(
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Saldo disponível',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    // FittedBox garantindo que saldos gigantes não quebrem a tela
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'R\$ ${saldo.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              _buildMiniCard('Ganhos', ganhos, AppColors.emeraldColor),
              const SizedBox(width: 12),
              _buildMiniCard('Gastos', gastos, Colors.orangeAccent),
              const SizedBox(width: 12),
              _buildMiniCard('Meta', meta, AppColors.indigoColor),
            ],
          ),
          const SizedBox(height: 32),
          _buildProgressRow('Projeção IA', projecao, wProj, AppColors.primary),
          const SizedBox(height: 16),
          _buildProgressRow('Real', gastos, wReal, AppColors.emeraldColor),
        ],
      ),
    );
  }

  Widget _buildMiniCard(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        // Reduzi levemente o padding para aproveitar melhor o espaço em telas pequenas
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.slate800,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FittedBox no Label (Ganhos, Gastos, Meta)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // FittedBox no Valor (R$ 0.00)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'R\$ ${_formatarMoeda(amount)}',
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textPrimary)),
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

import 'package:flutter/material.dart';
import '../core/app_config.dart';
import '../services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Tela2Feed extends StatefulWidget {
  final String mesReferencia;

  const Tela2Feed({super.key, required this.mesReferencia});

  @override
  State<Tela2Feed> createState() => _Tela2FeedState();
}

class _Tela2FeedState extends State<Tela2Feed> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _feedFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant Tela2Feed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mesReferencia != widget.mesReferencia) {
      _loadData();
    }
  }

  void _loadData() {
    // Busca o token da sessão atual do Supabase
    final session = Supabase.instance.client.auth.currentSession;
    final token = session?.accessToken ?? '';

    setState(() {
      _feedFuture = _apiService.getFeed(widget.mesReferencia, token);
    });
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
    
    // --- INÍCIO DA CORREÇÃO DE SEGURANÇA ---
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

    // 1. Limpa a string da categoria
    String rawCategory = item['categoria']?.toString() ?? 'Outros';
    
    // 2. Corrige a falta de acentuação (comum em respostas de IA JSON)
    const mapAcentos = {
      'Alimentacao': 'Alimentação',
      'Saude': 'Saúde',
      'Educacao': 'Educação',
      'Transferencia': 'Transferência',
      'Servicos': 'Serviços',
    };
    rawCategory = mapAcentos[rawCategory] ?? rawCategory;

    // 3. Trava de segurança: Se a IA enviar uma categoria inventada, forçamos 'Outros'
    if (!categorias.contains(rawCategory)) {
      rawCategory = 'Outros';
    }
    var categoriaSelecionada = rawCategory;

    // 4. Trava de segurança para o ícone
    String rawIcon = item['icon']?.toString() ?? 'help_outline';
    if (!icones.contains(rawIcon)) {
      rawIcon = 'help_outline';
    }
    var iconeSelecionado = rawIcon;
    // --- FIM DA CORREÇÃO ---

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
                    if (value != null) categoriaSelecionada = value;
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
                    if (value != null) iconeSelecionado = value;
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
              onPressed: () {
                // TODO: Aqui depois conectaremos a sua API para Salvar no Supabase
                Navigator.of(context).pop();
              },
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
      future: _feedFuture,
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
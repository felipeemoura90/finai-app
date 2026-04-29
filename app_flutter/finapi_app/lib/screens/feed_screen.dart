import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/theme/app_colors.dart';

// 1. Agora a tela é STATEFUL (tem vida/estado e aceita setState!)
class Tela2Feed extends StatefulWidget {
  final String mesReferencia;

  const Tela2Feed({super.key, required this.mesReferencia});

  @override
  State<Tela2Feed> createState() => _Tela2FeedState();
}

class _Tela2FeedState extends State<Tela2Feed> {
  Future<List<dynamic>> fetchFeed() async {
    // Atenção: Use a rota correta do seu Python (transacoes, extrato, etc)
    // Note que agora usamos widget.mesReferencia por ser Stateful
    final url = Uri.parse(
      'http://127.0.0.1:8000/api/feed?mes=${widget.mesReferencia}',
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
      case 'help_outline':
        return Icons.help_outline;
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

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 800;

    return FutureBuilder<List<dynamic>>(
      future:
          fetchFeed(), // Toda vez que chamarmos setState, ele busca de novo!
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

                // 2. AQUI ESTÁ O BOTÃO (InkWell) ENVOLVENDO O CARTÃO!
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () =>
                        _mostrarDialogoRegra(context, item), // Abre o editor!
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
                                      ? AppColors.emeraldColor.withValues(
                                          alpha: 0.1,
                                        )
                                      : trust == 'ai'
                                      ? Colors.blue.withValues(alpha: 0.1)
                                      : Colors.amber.withValues(alpha: 0.1),
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

  // --- O CÉREBRO DA EDIÇÃO ---
  void _mostrarDialogoRegra(BuildContext context, Map<String, dynamic> item) {
    TextEditingController keywordCtrl = TextEditingController(
      text: item['raw'],
    );
    TextEditingController nameCtrl = TextEditingController(text: item['name']);
    String catSelecionada = item['categoria'] ?? 'Outros';
    String iconeSelecionado = item['icon'] ?? 'help_outline';

    List<String> categorias = [
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
    List<String> icones = [
      'shopping_cart',
      'restaurant',
      'bolt',
      'wifi',
      'local_pharmacy',
      'local_gas_station',
      'school',
      'compare_arrows',
      'help_outline',
      'payment',
      'local_cafe',
    ];

    // Se a categoria do Python não estiver na lista padrão, usa 'Outros' para não dar erro
    if (!categorias.contains(catSelecionada)) catSelecionada = 'Outros';
    if (!icones.contains(iconeSelecionado)) iconeSelecionado = 'help_outline';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.bgCard,
              title: const Text(
                'Ensinar Regra de Limpeza',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Palavra-chave no Extrato:',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: keywordCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: _inputDeco(),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Nome Limpo (Como deve aparecer):',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: _inputDeco(),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Categoria:',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: catSelecionada,
                      dropdownColor: AppColors.slate800,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: _inputDeco(),
                      items: categorias
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setStateDialog(() => catSelecionada = val!),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Ícone Visual:',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: iconeSelecionado,
                      dropdownColor: AppColors.slate800,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: _inputDeco(),
                      items: icones
                          .map(
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Row(
                                children: [
                                  Icon(
                                    _getIconData(i),
                                    color: AppColors.emeraldColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(i),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setStateDialog(() => iconeSelecionado = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emeraldColor,
                  ),
                  onPressed: () async {
                    Map<String, String> payload = {
                      "keyword": keywordCtrl.text,
                      "name": nameCtrl.text,
                      "categoria": catSelecionada,
                      "icon": iconeSelecionado,
                    };

                    await http.post(
                      Uri.parse('http://127.0.0.1:8000/api/regras'),
                      headers: {"Content-Type": "application/json"},
                      body: jsonEncode(payload),
                    );

                    if (context.mounted) {
                      Navigator.pop(context); // Fecha a janela
                      setState(
                        () {},
                      ); // 3. AQUI A MÁGICA: A tela atualiza sozinha!
                    }
                  },
                  child: const Text(
                    'Salvar Regra',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDeco() {
    return InputDecoration(
      filled: true,
      fillColor: AppColors.slate800,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.emeraldColor),
      ),
    );
  }
}

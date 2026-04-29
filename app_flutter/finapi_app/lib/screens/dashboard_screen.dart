import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/theme/app_colors.dart';

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
      'http://127.0.0.1:8000/api/dashboard?mes=$mesReferencia&meta_mensal=$metaMensal',
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['data'];
    } else {
      throw Exception('Falha ao carregar dados');
    }
  }

  // --- BLINDAGEM DE DADOS ---
  // Transforma qualquer coisa que venha da API em um número Double seguro
  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Formata a moeda já garantindo que o valor é válido (Evita o erro dartx.toStringAsFixed)
  String _formatarMoeda(dynamic valor) {
    double numeroSeguro = _safeDouble(valor);
    return numeroSeguro.toStringAsFixed(2);
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

        // Lendo os dados de forma 100% segura
        final double ganhos = _safeDouble(data['ganhos']);
        final double gastos = _safeDouble(data['gastos']);
        final double saldo = _safeDouble(data['saldo']);
        final double meta = _safeDouble(data['meta']);
        final double projecaoIa = _safeDouble(data['projecao_ia']);
        final String insight =
            data['insight_ia'] ?? 'Nenhum insight disponível.';
        final List categorias = data['categorias'] ?? [];

        // Proteção contra divisão por zero
        double wReal = meta > 0 ? (gastos / meta).clamp(0.0, 1.0) : 0.0;
        double wProj = meta > 0 ? (projecaoIa / meta).clamp(0.0, 1.0) : 0.0;

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
                      color: AppColors.emeraldColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.emeraldColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.emeraldColor),
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
                      "Nenhum gasto registrado neste mês.",
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
                          // Leitura segura
                          double valorCat = _safeDouble(cat['valor']);
                          double porcentagem = gastos > 0
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
                                    // Usando a nova função blindada!
                                    Text(
                                      'R\$ ${_formatarMoeda(valorCat)}',
                                      style: const TextStyle(color: AppColors.textPrimary),
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
        // Saldo Real do Mês
        Container(
          width: double.infinity, // Ocupa toda a largura disponível
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.slate800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saldo Real do Mês',
                style: TextStyle(color: AppColors.textMuted, fontSize: 16),
              ),
              const SizedBox(height: 12),
              // NOVO: Sem Row! Apenas o texto puro, para ele quebrar linha sozinho
              Text(
                'Você ganhou R\$ ${_formatarMoeda(ganhos)}, gastou R\$ ${_formatarMoeda(gastos)},\nSobraram R\$ ${_formatarMoeda(saldo)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w300,
                  height: 1.5, // Dá um respiro legal entre as linhas
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Gasto vs. Meta
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.slate800),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gasto vs. Meta',
                style: TextStyle(color: AppColors.textMuted, fontSize: 16),
              ),
              const SizedBox(height: 12),
              // NOVO: Usando 'Wrap' ao invés de 'Row'. O Wrap joga os itens para a linha debaixo se faltar espaço!
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(
                    'R\$ ${_formatarMoeda(gastos)}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 40,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '/ R\$ ${_formatarMoeda(meta)}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.slate800,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: wProj,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: wReal,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.emeraldColor,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emeraldColor.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12, // Espaço se quebrar linha
                children: [
                  _buildLegend(AppColors.emeraldColor, 'Gasto Atual'),
                  _buildLegend(
                    Colors.amber,
                    'Projeção: R\$ ${_formatarMoeda(projecao)}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }

  Color _getColorForCategory(String categoryName) {
    switch (categoryName) {
      case 'Mercado':
        return Colors.blueAccent;
      case 'Contas Fixas':
        return Colors.orangeAccent;
      case 'Alimentação':
        return Colors.redAccent;
      case 'Transporte':
        return Colors.purpleAccent;
      case 'Educação':
        return Colors.indigoAccent;
      case 'Transferência':
        return Colors.tealAccent;
      case 'Saúde':
        return Colors.pinkAccent;
      default:
        return Colors.blueGrey;
    }
  }
}

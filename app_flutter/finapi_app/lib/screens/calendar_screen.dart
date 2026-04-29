import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme/app_colors.dart';

class Tela3Calendar extends StatelessWidget {
  final String mesReferencia;

  const Tela3Calendar({super.key, required this.mesReferencia});

  Future<List<dynamic>> fetchFluxo() async {
    final url = Uri.parse('http://127.0.0.1:8000/api/fluxo?mes=$mesReferencia');
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
              'Erro ao carregar dados do gráfico.',
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

        // --- PREPARANDO OS DADOS ---
        List<FlSpot> pontosDoGrafico = [];

        // Pega o primeiro valor de saldo como base para achar o topo e o fundo do poço
        double maxSaldo = _safeDouble(dados.first['valor']);
        double minSaldo = _safeDouble(dados.first['valor']);

        for (var item in dados) {
          double dia = _safeDouble(item['dia']);
          double valor = _safeDouble(item['valor']);

          pontosDoGrafico.add(FlSpot(dia, valor));

          if (valor > maxSaldo) maxSaldo = valor;
          if (valor < minSaldo) minSaldo = valor;
        }

        // Calcula dinamicamente o chão e o teto do gráfico para ele não ficar achatado
        double padding = (maxSaldo - minSaldo).abs() * 0.2; // 20% de respiro
        if (padding == 0) padding = 100;

        double tetoGrafico = maxSaldo + padding;
        double chaoGrafico = minSaldo < 0
            ? minSaldo - padding
            : 0; // Se o saldo ficar negativo, o chão afunda!

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Histórico de Saldo Acumulado',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'O saldo carregado dos meses anteriores sofrendo o impacto de ganhos e gastos.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 32),

                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(
                        right: 40,
                        left: 16,
                        top: 40,
                        bottom: 24,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.slate800),
                      ),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (value) {
                              // Desenha uma linha mais forte no "Zero" se a pessoa entrar no negativo
                              return FlLine(
                                color: value == 0
                                    ? Colors.redAccent.withValues(alpha: 0.5)
                                    : AppColors.slate800,
                                strokeWidth: value == 0 ? 2 : 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 30,
                                interval: 5,
                                getTitlesWidget: (value, meta) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 10.0),
                                    child: Text(
                                      'Dia ${value.toInt()}',
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 60,
                                interval: (tetoGrafico - chaoGrafico) > 0
                                    ? ((tetoGrafico - chaoGrafico) / 5)
                                          .floorToDouble()
                                    : 100,
                                getTitlesWidget: (value, meta) {
                                  if (value == chaoGrafico ||
                                      value == tetoGrafico)
                                    return const SizedBox.shrink(); // Limpa as pontas
                                  // Formata em milhares (ex: 5k) se o valor for muito grande para caber na tela
                                  String label = value >= 1000
                                      ? '${(value / 1000).toStringAsFixed(1)}k'
                                      : value.toInt().toString();
                                  return Text(
                                    'R\$ $label',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 12,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 1,
                          maxX: pontosDoGrafico.length.toDouble(),
                          minY: chaoGrafico,
                          maxY: tetoGrafico,
                          lineBarsData: [
                            LineChartBarData(
                              spots: pontosDoGrafico,
                              isCurved: true,
                              preventCurveOverShooting: true,
                              color: AppColors.emeraldColor,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  // Como agora é saldo acumulado diário, mostrar bolinha apenas se houver movimentação no dia
                                  double mov = _safeDouble(
                                    dados[index]['movimento'],
                                  );
                                  return FlDotCirclePainter(
                                    radius: mov != 0 ? 4 : 0,
                                    color: AppColors.bgCard,
                                    strokeWidth: 2,
                                    strokeColor: AppColors.emeraldColor,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppColors.emeraldColor.withValues(alpha: 0.1),
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (touchedSpot) => AppColors.slate800,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((
                                  LineBarSpot touchedSpot,
                                ) {
                                  return LineTooltipItem(
                                    'Dia ${touchedSpot.x.toInt()}\nSaldo: R\$ ${touchedSpot.y.toStringAsFixed(2)}',
                                    const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      height: 1.5,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                        ),
                      ),
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
}

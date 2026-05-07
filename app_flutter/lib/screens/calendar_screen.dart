import 'package:flutter/material.dart';
import '../core/app_config.dart';
import '../services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Tela3Calendar extends StatefulWidget {
  final String mesReferencia;

  const Tela3Calendar({super.key, required this.mesReferencia});

  @override
  State<Tela3Calendar> createState() => _Tela3CalendarState();
}

class _Tela3CalendarState extends State<Tela3Calendar> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> _fluxoFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant Tela3Calendar oldWidget) {
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
      _fluxoFuture = _apiService.getFluxo(widget.mesReferencia, token);
    });
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
      future: _fluxoFuture,
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

        final parts = widget.mesReferencia.split('-');
        final int year = int.parse(parts[0]);
        final int month = int.parse(parts[1]);
        final DateTime firstDay = DateTime(year, month, 1);
        final int startOffset = firstDay.weekday == 7 ? 0 : firstDay.weekday;

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
                      if (index < startOffset) return const SizedBox.shrink();

                      final dayIndex = index - startOffset;
                      final diaData = dados[dayIndex];
                      final int diaNum = diaData['dia'];
                      final double mov = _safeDouble(diaData['movimento']);
                      final double saldo = _safeDouble(diaData['valor']);
                      final List transacoes =
                          (diaData['transacoes'] as List?) ?? [];

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
    Color textColor = AppColors.textPrimary;

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

                      // Tenta pegar a descrição, se não achar tenta 'name', se não achar joga 'Evento'
                      final String nomeTransacao =
                          transacao['descricao']?.toString() ??
                          transacao['name']?.toString() ??
                          'Evento';

                      // Tenta pegar o valor pelas chaves possíveis
                      final dynamic valorBruto =
                          transacao['valor'] ??
                          transacao['value'] ??
                          transacao['amount'];

                      // Regra para não quebrar caso a API mande string formatada (ex: "R$ 50,00")
                      // ao invés de float numérico
                      String valorFormatado;
                      if (valorBruto is String &&
                          valorBruto.toUpperCase().contains('R\$')) {
                        valorFormatado = valorBruto;
                      } else {
                        valorFormatado =
                            'R\$ ${_safeDouble(valorBruto).toStringAsFixed(2)}';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                nomeTransacao,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              valorFormatado,
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

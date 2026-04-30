import 'package:flutter/material.dart';
import '../core/app_config.dart';

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

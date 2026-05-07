import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/app_config.dart';
import '../screens/dashboard_screen.dart';
import '../screens/feed_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/settings_screen.dart';
import '../providers/auth_provider.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _activeTab = 0;
  DateTime _mesAtual = DateTime.now();
  double _metaAtual = 3000.0;

  String get _mesFormatadoAPI => DateFormat('yyyy-MM').format(_mesAtual);
  String get _mesFormatadoDisplay =>
      DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual);

  void _mudarMes(int meses) {
    setState(() {
      _mesAtual = DateTime(_mesAtual.year, _mesAtual.month + meses);
    });
  }

  void _abrirDialogoMeta(BuildContext context) {
    TextEditingController controller = TextEditingController(
      text: _metaAtual.toStringAsFixed(2),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text(
          'Definir Meta',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            prefixText: 'R\$ ',
            filled: true,
            fillColor: AppColors.slate800,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _metaAtual =
                    double.tryParse(controller.text.replaceAll(',', '.')) ??
                    _metaAtual;
              });
              Navigator.pop(context);
            },
            child: const Text(
              'Salvar',
              style: TextStyle(color: AppColors.emeraldColor),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> get _screens => [
    Tela1Dashboard(mesReferencia: _mesFormatadoAPI, metaMensal: _metaAtual),
    Tela2Feed(mesReferencia: _mesFormatadoAPI),
    Tela3Calendar(mesReferencia: _mesFormatadoAPI),
    const Tela4Settings(),
  ];

  void _handleLogout(BuildContext context, AuthProvider authProvider) async {
    await authProvider.signOut();
  }

  Future<void> _importarArquivo() async {
    // Sua lógica de importação existente...
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;
        final authProvider = context.read<AuthProvider>();

        return Scaffold(
          // Chat temporariamente desativado; botão removido da interface.
          body: isDesktop
              ? Row(
                  children: [
                    Container(
                      width: 260,
                      color: AppColors.bgSidebar,
                      child: _AppSidebar(
                        activeTab: _activeTab,
                        onTabSelected: (index) =>
                            setState(() => _activeTab = index),
                        onImport: _importarArquivo,
                        onLogout: () => _handleLogout(context, authProvider),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _DesktopHeader(
                            monthLabel: _mesFormatadoDisplay,
                            metaValue: _metaAtual,
                            onPrevious: () => _mudarMes(-1),
                            onNext: () => _mudarMes(1),
                            onEditMeta: () => _abrirDialogoMeta(context),
                          ),
                          Expanded(
                            child: IndexedStack(
                              index: _activeTab,
                              children: _screens,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _MobileAppBar(
                      onImport: _importarArquivo,
                      onLogout: () => _handleLogout(context, authProvider),
                    ),
                    _MobileToolbar(
                      monthLabel: _mesFormatadoDisplay,
                      metaValue: _metaAtual,
                      onPrevious: () => _mudarMes(-1),
                      onNext: () => _mudarMes(1),
                      onEditMeta: () => _abrirDialogoMeta(context),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _activeTab,
                        children: _screens,
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: isDesktop
              ? null
              : BottomNavigationBar(
                  backgroundColor: AppColors.bgSidebar,
                  selectedItemColor: AppColors.emeraldColor,
                  unselectedItemColor: AppColors.textMuted,
                  currentIndex: _activeTab,
                  type: BottomNavigationBarType.fixed,
                  onTap: (index) => setState(() => _activeTab = index),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_rounded),
                      label: 'Dashboard',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.bolt_rounded),
                      label: 'Feed',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.calendar_month_rounded),
                      label: 'Fluxo',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.settings_rounded),
                      label: 'Metas',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

// --- WIDGETS AUXILIARES (DEFININDO O QUE ESTAVA FALTANDO) ---

class _MobileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onImport;
  final VoidCallback onLogout;
  const _MobileAppBar({required this.onImport, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bgSidebar,
      elevation: 0,
      centerTitle: true,
      leading: _MobileProfileMenu(onImport: onImport, onLogout: onLogout),
      title: const Text(
        'FinAI.',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _MobileToolbar extends StatelessWidget {
  final String monthLabel;
  final double metaValue;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onEditMeta;

  const _MobileToolbar({
    required this.monthLabel,
    required this.metaValue,
    required this.onPrevious,
    required this.onNext,
    required this.onEditMeta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.background,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.textMuted,
                ),
                onPressed: onPrevious,
              ),
              Text(
                monthLabel.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                ),
                onPressed: onNext,
              ),
            ],
          ),
          ActionChip(
            label: Text('R\$ ${metaValue.toStringAsFixed(0)}'),
            backgroundColor: AppColors.emeraldColor.withOpacity(0.1),
            onPressed: onEditMeta,
          ),
        ],
      ),
    );
  }
}

class _AppSidebar extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onImport;
  final VoidCallback onLogout;

  const _AppSidebar({
    required this.activeTab,
    required this.onTabSelected,
    required this.onImport,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 48),
        const Text(
          'FinAI.',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 32),
        _NavItem(
          icon: Icons.dashboard,
          label: 'Dashboard',
          isActive: activeTab == 0,
          onTap: () => onTabSelected(0),
        ),
        _NavItem(
          icon: Icons.bolt,
          label: 'Feed',
          isActive: activeTab == 1,
          onTap: () => onTabSelected(1),
        ),
        _NavItem(
          icon: Icons.calendar_today,
          label: 'Fluxo',
          isActive: activeTab == 2,
          onTap: () => onTabSelected(2),
        ),
        _NavItem(
          icon: Icons.settings,
          label: 'Metas',
          isActive: activeTab == 3,
          onTap: () => onTabSelected(3),
        ),
        const Spacer(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Sair'),
          onTap: onLogout,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isActive ? AppColors.emeraldColor : AppColors.textMuted,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? AppColors.textPrimary : AppColors.textMuted,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _MobileProfileMenu extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onLogout;
  const _MobileProfileMenu({required this.onImport, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.person_outline),
      onPressed: () {
        // Menu simples ou navegação para perfil
      },
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  final String monthLabel;
  final double metaValue;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onEditMeta;

  const _DesktopHeader({
    required this.monthLabel,
    required this.metaValue,
    required this.onPrevious,
    required this.onNext,
    required this.onEditMeta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.slate800)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPrevious,
              ),
              Text(
                monthLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNext,
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: onEditMeta,
            icon: const Icon(Icons.edit),
            label: Text('Meta: R\$ $metaValue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldColor,
            ),
          ),
        ],
      ),
    );
  }
}

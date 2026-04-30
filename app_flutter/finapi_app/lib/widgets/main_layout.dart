import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/app_config.dart';
import '../screens/dashboard_screen.dart';
import '../screens/feed_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/settings_screen.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart'; // <-- NOVO: Importando nosso Service
import 'package:supabase_flutter/supabase_flutter.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final ApiService _apiService = ApiService(); // <-- NOVO: Instância do Service
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
          'Definir Meta do Mês',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            prefixText: 'R\$ ',
            prefixStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.slate800,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.emeraldColor),
            ),
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

  // CORREÇÃO: Removidas as chaves dinâmicas que destruíam o estado da tela!
  // Agora o Flutter vai reusar os widgets e chamar o didUpdateWidget lindamente.
  List<Widget> get _screens => [
    Tela1Dashboard(mesReferencia: _mesFormatadoAPI, metaMensal: _metaAtual),
    Tela2Feed(mesReferencia: _mesFormatadoAPI),
    Tela3Calendar(mesReferencia: _mesFormatadoAPI),
    const Tela4Settings(),
  ];

  void _handleLogout(BuildContext context, AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Confirmar Logout',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Tem certeza que deseja sair?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authProvider.signOut();
    }
  }

  Future<void> _importarArquivo() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Arquivos Financeiros',
        extensions: <String>['ofx', 'csv', 'xlsx'],
      );

      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );

      if (file != null) {
        final fileBytes = await file.readAsBytes();
        final fileName = file.name;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enviando arquivo para o servidor...'),
              backgroundColor: AppColors.indigoColor,
            ),
          );
        }
        final session = Supabase.instance.client.auth.currentSession;
        final token = session?.accessToken ?? '';
        // CORREÇÃO: Usando o ApiService em vez de fazer a requisição HTTP crua aqui
        final success = await _apiService.uploadFile(
          fileBytes,
          fileName,
          token,
        );

        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Arquivo processado com sucesso!'),
              backgroundColor: AppColors.emeraldColor,
            ),
          );
          // Atualiza as telas após o upload
          setState(() {});
        } else {
          throw Exception('Erro no servidor Python ao processar o arquivo.');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao importar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;
        final authProvider = context.read<AuthProvider>();

        if (isDesktop) {
          return Scaffold(
            body: Row(
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
                      // CORREÇÃO: A chave dinâmica aqui também foi removida.
                      // O IndexedStack é melhor pois mantém TODAS as telas vivas,
                      // mudando apenas qual está visível. Melhora muito a performance de navegação!
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
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.bgSidebar,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
            leading: _MobileProfileMenu(
              onImport: _importarArquivo,
              onLogout: () => _handleLogout(context, authProvider),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.show_chart_rounded,
                  color: AppColors.emeraldColor,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'FinAI.',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none,
                  color: AppColors.textMuted,
                ),
                onPressed: () {},
              ),
            ],
          ),
          body: Column(
            children: [
              _MobileToolbar(
                monthLabel: _mesFormatadoDisplay,
                metaValue: _metaAtual,
                onPrevious: () => _mudarMes(-1),
                onNext: () => _mudarMes(1),
                onEditMeta: () => _abrirDialogoMeta(context),
              ),
              Expanded(
                child: IndexedStack(index: _activeTab, children: _screens),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
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

// ============================================================================
// WIDGETS AUXILIARES ABAIXO (Nenhuma alteração lógica necessária aqui)
// ============================================================================

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
        if (MediaQuery.of(context).size.width >= 800) const _SidebarLogo(),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  isActive: activeTab == 0,
                  onTap: () => onTabSelected(0),
                ),
                _NavItem(
                  icon: Icons.bolt_rounded,
                  label: 'Feed de Automação',
                  isActive: activeTab == 1,
                  onTap: () => onTabSelected(1),
                ),
                _NavItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Fluxo de Caixa',
                  isActive: activeTab == 2,
                  onTap: () => onTabSelected(2),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: 'Metas e Lógica',
                  isActive: activeTab == 3,
                  onTap: () => onTabSelected(3),
                ),
              ],
            ),
          ),
        ),
        _UserProfileMenu(onImport: onImport, onLogout: onLogout),
      ],
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  const _SidebarLogo();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.emeraldColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.show_chart_rounded,
              color: AppColors.emeraldColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'FinAI',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Text(
            '.',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.emeraldColor,
            ),
          ),
        ],
      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.bgCard : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive ? Border.all(color: AppColors.slate800) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? AppColors.emeraldColor : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserProfileMenu extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onLogout;

  const _UserProfileMenu({required this.onImport, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final String nome = user?.userMetadata?['full_name'] ?? 'Usuário';
    final String email = user?.email ?? 'email@indisponivel.com';
    final String? fotoUrl = user?.userMetadata?['avatar_url'];

    return PopupMenuButton<String>(
      offset: const Offset(0, -120),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'importar_ofx')
          onImport();
        else if (value == 'sair')
          onLogout();
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'importar_ofx',
          child: Row(
            children: [
              Icon(Icons.upload_file, color: AppColors.emeraldColor),
              SizedBox(width: 8),
              Text(
                'Importar arquivo OFX',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'sair',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Sair', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.slate800)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.2),
              backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
              onBackgroundImageError: fotoUrl != null ? (e, s) {} : null,
              child: fotoUrl == null
                  ? Text(
                      nome.isNotEmpty ? nome[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    email,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MobileProfileMenu extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onLogout;

  const _MobileProfileMenu({required this.onImport, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final String nome = user?.userMetadata?['full_name'] ?? 'Usuário';
    final String email = user?.email ?? '';
    final String? fotoUrl = user?.userMetadata?['avatar_url'];

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'importar_ofx')
          onImport();
        else if (value == 'sair')
          onLogout();
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'importar_ofx',
          child: Row(
            children: [
              Icon(Icons.upload_file, color: AppColors.emeraldColor),
              SizedBox(width: 8),
              Text(
                'Importar Extrato',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'sair',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Sair', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          enabled: false,
          height: 40,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nome,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (email.isNotEmpty)
                Text(
                  email,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary.withOpacity(0.2),
          backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
          onBackgroundImageError: fotoUrl != null ? (e, s) {} : null,
          child: fotoUrl == null
              ? Text(
                  nome.isNotEmpty ? nome[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                )
              : null,
        ),
      ),
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
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.slate800)),
      ),
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
              const SizedBox(width: 8),
              Text(
                monthLabel.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                ),
                onPressed: onNext,
              ),
              const SizedBox(width: 24),
              InkWell(
                onTap: onEditMeta,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.emeraldColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.track_changes,
                        color: AppColors.emeraldColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Meta: R\$ ${metaValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.emeraldColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: TextField(
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Pergunte à IA...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppColors.bgCard,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: AppColors.slate800),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: AppColors.emeraldColor.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.bgSidebar,
        border: Border(bottom: BorderSide(color: AppColors.slate800)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.chevron_left,
                  color: AppColors.textMuted,
                ),
                onPressed: onPrevious,
              ),
              const SizedBox(width: 8),
              Text(
                monthLabel.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textMuted,
                ),
                onPressed: onNext,
              ),
            ],
          ),
          InkWell(
            onTap: onEditMeta,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.emeraldColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.emeraldColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.track_changes,
                    color: AppColors.emeraldColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Meta: R\$ ${metaValue.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.emeraldColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

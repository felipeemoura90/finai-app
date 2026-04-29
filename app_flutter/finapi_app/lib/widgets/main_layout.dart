import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
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
  double _metaAtual = 3000.0; // <-- NOVO: Variável global da meta

  String get _mesFormatadoAPI => DateFormat('yyyy-MM').format(_mesAtual);
  String get _mesFormatadoDisplay =>
      DateFormat('MMMM yyyy', 'pt_BR').format(_mesAtual);

  void _mudarMes(int meses) {
    setState(() {
      _mesAtual = DateTime(_mesAtual.year, _mesAtual.month + meses);
    });
  }

  // NOVO: Função para abrir a caixinha de alterar a meta
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
            focusedBorder: OutlineInputBorder(
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
                // Converte o texto para número (trocando vírgula por ponto se precisar)
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

  // Atualizamos as telas para receber a meta!
  List<Widget> get _screens => [
    Tela1Dashboard(
      key: ValueKey('dash-$_mesFormatadoAPI-$_metaAtual'),
      mesReferencia: _mesFormatadoAPI,
      metaMensal: _metaAtual,
    ),
    Tela2Feed(
      key: ValueKey('feed-$_mesFormatadoAPI'),
      mesReferencia: _mesFormatadoAPI,
    ),
    // ATUALIZE A TELA 3 AQUI:
    Tela3Calendar(
      key: ValueKey('fluxo-$_mesFormatadoAPI'),
      mesReferencia: _mesFormatadoAPI,
    ),
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
            child: Text(
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
      // 1. Configura quais arquivos podem ser selecionados
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Arquivos Financeiros',
        extensions: <String>['ofx', 'csv', 'xlsx'],
      );

      // 2. Abre a janela do sistema
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[typeGroup],
      );

      if (file != null) {
        // Pega os dados do arquivo selecionado
        final fileBytes = await file.readAsBytes();
        final fileName = file.name;

        // 3. Mostra o aviso visual
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enviando arquivo para o servidor...'),
              backgroundColor: AppColors.indigoColor,
            ),
          );
        }

        // 4. Monta o pacote de envio
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('http://127.0.0.1:8000/api/upload'),
        );

        request.files.add(
          http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
        );

        // 5. Dispara para o Python
        var response = await request.send();

        if (response.statusCode == 200 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Arquivo processado com sucesso!'),
              backgroundColor: AppColors.emeraldColor,
            ),
          );
          setState(() {}); // Atualiza a tela
        } else {
          throw Exception('Erro no servidor Python');
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

        final mainArea = Column(
          children: [
            if (isDesktop) _buildHeader(),
            Expanded(
              // Essa linha com 'Key' é a mágica que força a tela a piscar e buscar dados novos
              key: ValueKey('$_activeTab-$_mesFormatadoAPI'),
              child: _screens[_activeTab],
            ),
          ],
        );

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: 260,
                  color: AppColors.bgSidebar,
                  child: _buildSidebarContent(),
                ),
                Expanded(child: mainArea),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.bgSidebar,
            elevation: 0,
            iconTheme: const IconThemeData(color: AppColors.textPrimary),
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
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'logout') {
                        _handleLogout(context, authProvider);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              authProvider.user?.email ?? 'Usuário',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Sair', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: Text(
                        authProvider.user?.email
                                ?.substring(0, 1)
                                .toUpperCase() ??
                            'U',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          drawer: Drawer(
            backgroundColor: AppColors.bgSidebar,
            child: SafeArea(child: _buildSidebarContent()),
          ),
          body: mainArea,
        );
      },
    );
  }

  // --- MÉTODOS DA BARRA LATERAL QUE HAVIAM SUMIDO ---

  Widget _buildSidebarContent() {
    return Column(
      children: [
        if (MediaQuery.of(context).size.width >= 800) _buildLogo(),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildNavItem(Icons.dashboard_rounded, 'Dashboard', 0),
                _buildNavItem(Icons.bolt_rounded, 'Feed de Automação', 1),
                _buildNavItem(
                  Icons.calendar_month_rounded,
                  'Fluxo de Caixa',
                  2,
                ),
                _buildNavItem(Icons.settings_rounded, 'Metas e Lógica', 3),
              ],
            ),
          ),
        ),
        _buildUserProfile(),
      ],
    );
  }

  Widget _buildLogo() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.emeraldColor.withValues(alpha: 0.2),
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

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isActive = _activeTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
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

  Widget _buildUserProfile() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    final String nome = user?.userMetadata?['full_name'] ?? 'Usuário';
    final String email = user?.email ?? 'email@indisponivel.com';
    final String? fotoUrl = user?.userMetadata?['avatar_url'];

    // 1. Envolvemos tudo em um PopupMenuButton para criar o menu clicável
    return PopupMenuButton<String>(
      // Offset negativo para o menu abrir "para cima", já que o botão fica no fim da tela
      offset: const Offset(0, -120),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'importar_ofx') {
          _importarArquivo(); // <--- CHAMA A FUNÇÃO AQUI
        } else if (value == 'sair') {
          _handleLogout(context, authProvider);
        }
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
      // O child é o desenho da barra lateral que será clicável
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.slate800)),
        ),
        child: Row(
          children: [
            // 2. Avatar blindado contra erros de carregamento (CORS)
            CircleAvatar(
              backgroundColor: AppColors.primary.withOpacity(0.2),
              backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
              onBackgroundImageError: fotoUrl != null
                  ? (exception, stackTrace) {
                      // Silencia o erro se a imagem for bloqueada pelo navegador
                    }
                  : null,
              // Fallback: Mostra a primeira letra do nome se a foto falhar ou não existir
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
            // 3. Um pequeno ícone de opções para o usuário entender que é clicável
            const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  // --- CABEÇALHO COM CONTROLE DE MÊS ---

  Widget _buildHeader() {
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
                onPressed: () => _mudarMes(-1),
              ),
              const SizedBox(width: 8),
              Text(
                _mesFormatadoDisplay.toUpperCase(),
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
                onPressed: () => _mudarMes(1),
              ),

              const SizedBox(width: 24), // Espaço separador
              // NOVO: Botão interativo da Meta
              InkWell(
                onTap: () => _abrirDialogoMeta(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.emeraldColor.withValues(alpha: 0.3),
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
                        'Meta: R\$ ${_metaAtual.toStringAsFixed(2)}',
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
                      color: AppColors.emeraldColor.withValues(alpha: 0.5),
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

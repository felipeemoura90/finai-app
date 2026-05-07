import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/feed_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/settings_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // Lista das suas abas (certifique-se que os imports batem com o seu projeto)
  final List<Widget> _screens = [
    DashboardScreen(),
    FeedScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  // Função fictícia para o seu upload (conecte à sua lógica real de FilePicker)
  void _importarExtrato() {
    // TODO: Adicione a sua lógica de chamar o ApiService.uploadFile aqui
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Funcionalidade de upload a caminho...")),
    );
  }

  @override
  Widget build(BuildContext context) {
    // O Provider agora nos entrega os dados fresquinhos e com segurança!
    final authProvider = Provider.of<AuthProvider>(context);
    
    // Verifica a largura do ecrã: se for maior que 600px, consideramos Web/Desktop
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    // Componente da foto de perfil com um ícone de fallback caso não exista foto
    Widget profileImage = authProvider.userPhoto != null
        ? CircleAvatar(
            backgroundImage: NetworkImage(authProvider.userPhoto!),
            radius: isDesktop ? 24 : 35,
          )
        : CircleAvatar(
            radius: isDesktop ? 24 : 35,
            child: const Icon(Icons.person, size: 30),
          );

    // ==========================================
    // LAYOUT WEB / DESKTOP (Ecrãs largos)
    // ==========================================
    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (int index) {
                setState(() => _currentIndex = index);
              },
              labelType: NavigationRailLabelType.all,
              // O TOPO do menu (Foto + Upload)
              leading: Column(
                children: [
                  const SizedBox(height: 20),
                  profileImage,
                  const SizedBox(height: 8),
                  Text(authProvider.userName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  FloatingActionButton(
                    elevation: 0,
                    onPressed: _importarExtrato,
                    tooltip: 'Importar Extrato',
                    child: const Icon(Icons.upload_file),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
              // A BASE do menu (Botão Sair)
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      onPressed: () => authProvider.signOut(),
                      tooltip: 'Sair',
                    ),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  selectedIcon: Icon(Icons.list_alt),
                  label: Text('Feed'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.calendar_today_outlined),
                  selectedIcon: Icon(Icons.calendar_today),
                  label: Text('Fluxo'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Ajustes'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      );
    }

    // ==========================================
    // LAYOUT MOBILE (Ecrãs estreitos)
    // ==========================================
    return Scaffold(
      appBar: AppBar(
        title: const Text('FinAI'),
        elevation: 0,
        centerTitle: true,
      ),
      // Aqui está o segredo: O menu lateral do Mobile que guarda a Foto e o Sair
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(authProvider.userName),
              accountEmail: Text(authProvider.userEmail),
              currentAccountPicture: profileImage,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Importar Extrato'),
              subtitle: const Text('Carregar ficheiro OFX'),
              onTap: () {
                Navigator.pop(context); // Fecha o Drawer antes de abrir o seletor
                _importarExtrato();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Sair', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                authProvider.signOut();
              },
            ),
          ],
        ),
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed, // Necessário quando há + de 3 itens
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Fluxo'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/app_config.dart';
import 'widgets/main_layout.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'widgets/splash_screen.dart';

void main() async {
  // Inicializa Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa a formatação de datas
  await initializeDateFormatting('pt_BR', null);

  // Inicializa o Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // Recomendado para mobile
    ),
  );

  runApp(const FinAIApp());
}

class FinAIApp extends StatelessWidget {
  const FinAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'FinAI Dashboard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        home: const AuthGuard(child: MainLayout()),
      ),
    );
  }
}

class AuthGuard extends StatelessWidget {
  final Widget child;
  const AuthGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          // Substituímos o Scaffold anterior por este:
          return const FinAiSplashScreen(); // <-- CARREGAMENTO COM STORYTELLING
        }

        if (!authProvider.isAuthenticated) {
          return const LoginScreen(); //[cite: 10]
        }

        return child; // Retorna o MainLayout[cite: 8]
      },
    );
  }
}

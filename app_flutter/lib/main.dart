import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/app_config.dart';
import 'widgets/main_layout.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
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

class AuthGuard extends StatefulWidget {
  final Widget child;
  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _checkingOnboarding = false;
  bool _needsOnboarding = false;
  bool _onboardingSkipped = false;
  bool _onboardingChecked = false;

  Future<void> _checkIfNeedsOnboarding() async {
    if (_onboardingChecked || _onboardingSkipped) return;

    setState(() => _checkingOnboarding = true);

    try {
      // Verifica diretamente no Supabase se o usuário possui QUALQUER transação salva.
      // O .limit(1) faz a consulta ser instantânea, pois só queremos saber se existe "pelo menos uma".
      final data = await Supabase.instance.client
          .from('transactions')
          .select('id')
          .limit(1);

      setState(() {
        // Se a lista 'data' vier vazia, ele precisa do onboarding.
        // Se tiver 1 item, a lista não é vazia, então _needsOnboarding = false e ele vai direto pro App!
        _needsOnboarding = data.isEmpty;
        _onboardingChecked = true;
        _checkingOnboarding = false;
      });
    } catch (e) {
      // Se der erro de conexão (ex: sem internet), pula o onboarding e tenta abrir o cache
      setState(() {
        _needsOnboarding = false;
        _onboardingChecked = true;
        _checkingOnboarding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const FinAiSplashScreen();
        }

        if (!authProvider.isAuthenticated) {
          // Reset onboarding state on logout
          _onboardingChecked = false;
          _onboardingSkipped = false;
          _needsOnboarding = false;
          return const LoginScreen();
        }

        // User is authenticated, check if needs onboarding
        if (!_onboardingChecked && !_onboardingSkipped) {
          if (!_checkingOnboarding) {
            // Agendar a verificação para depois do build terminar
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkIfNeedsOnboarding();
            });
          }
          return const FinAiSplashScreen(); // Show splash while checking
        }

        if (_needsOnboarding && !_onboardingSkipped) {
          return OnboardingScreen(
            onSkip: () {
              setState(() {
                _onboardingSkipped = true;
                _needsOnboarding = false;
              });
            },
            onComplete: () {
              setState(() {
                _needsOnboarding = false;
                _onboardingSkipped = true;
              });
            },
          );
        }

        return widget.child; // Retorna o MainLayout
      },
    );
  }
}

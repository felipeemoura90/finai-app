import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
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
  bool _onboardingSkipped = false;
  StreamSubscription<Uri>? _sub;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _processUri(Uri uri) async {
    if (!mounted) return;
    final code = uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.exchangeCodeForSession(code);
        // Sucesso: onAuthStateChange no AuthProvider vai lidar com o redirecionamento
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Erro ao finalizar login'),
              content: Text('Não foi possível trocar o código pela sessão.\n\nErro: $e'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
        }
      }
    } else {
      // URI chegou mas sem 'code' - mostrar o que chegou
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('URI sem código'),
            content: Text(uri.toString()),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
    }
  }

  void _initDeepLinks() async {
    // 1. Captura o link que ABRIU o app (cold start ou singleTask restart)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[DeepLink] Initial link: $initialUri');
        await _processUri(initialUri);
      }
    } catch (e) {
      debugPrint('[DeepLink] Erro ao obter initial link: $e');
    }

    // 2. Escuta links enquanto o app está em background
    _sub = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[DeepLink] Stream link: $uri');
        _processUri(uri);
      },
      onError: (e) => debugPrint('[DeepLink] Stream error: $e'),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const FinAiSplashScreen();
        }

        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        if (!authProvider.hasTransactions && !_onboardingSkipped) {
          return OnboardingScreen(
            onSkip: () => setState(() => _onboardingSkipped = true),
            onComplete: () => authProvider.checkUserTransactions(),
          );
        }

        return widget.child; // MainLayout
      },
    );
  }
}

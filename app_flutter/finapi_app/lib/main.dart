import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_colors.dart';
import 'widgets/main_layout.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_guard.dart';
import 'core/config/supabase_config.dart';

void main() async {
  // Inicializa Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa a formatação de datas
  await initializeDateFormatting('pt_BR', null);

  // Inicializa o Supabase
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const FinAIApp());
}
// ... (o resto do main.dart continua igual) ...

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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'platform_stub.dart' if (dart.library.io) 'platform_io.dart';

class AppColors {
  static const Color background = Color(0xFF0A0F16);
  static const Color surface = Color(0xFF131B26);
  static const Color primary = Color(0xFF10B981);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color bgSidebar = Color(0xFF0D141E);
  static const Color bgCard = Color(0xFF131B26);
  static const Color emeraldColor = Color(0xFF10B981);
  static const Color indigoColor = Color(0xFF6366F1);
  static const Color slate800 = Color(0xFF1E293B);
}

// ⚠️  NUNCA adicione valores reais aqui. Passe via --dart-define na build.
// Exemplo de uso:
//   flutter run -d web-server --web-port 3000 \
//     --dart-define=SUPABASE_URL=https://seu-projeto.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=sua_anon_key
// Ou em produção: --dart-define-from-file=.env.dart
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const String authCallbackUrl = 'finapi://auth/callback';

const bool isProduction = bool.fromEnvironment('dart.vm.product');

const String _envApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

String get apiBaseUrl {
  if (_envApiBaseUrl.isNotEmpty) {
    return _envApiBaseUrl;
  }

  if (kIsWeb) {
    return 'http://127.0.0.1:8000/api';
  }

  if (isAndroid) {
    return 'http://10.0.2.2:8000/api';
  }

  return 'http://127.0.0.1:8000/api';
}

double safeDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

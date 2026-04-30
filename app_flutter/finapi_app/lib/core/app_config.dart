import 'package:flutter/material.dart';

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

const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://fabengyjoxfwwszndohj.supabase.co',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_6r26DXJQqRit7K6sYcSXlA_jP9oxWvY',
);

const String authCallbackUrl = 'finapi://auth/callback';

const bool isProduction = bool.fromEnvironment('dart.vm.product');

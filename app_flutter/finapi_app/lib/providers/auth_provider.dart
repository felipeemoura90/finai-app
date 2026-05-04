import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../core/app_config.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _user;
  bool _isLoading = true;
  String? _errorMessage;

  StreamSubscription<AuthState>? _authSubscription;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _isLoading = true;
    notifyListeners();

    try {
      // O Supabase SDK gerencia a sessão automaticamente (salvando localmente).
      // Não precisamos do FlutterSecureStorage manualmente.
      _user = _supabase.auth.currentUser;

      // Escuta mudanças de estado de auth e intercepta logins / logouts
      _authSubscription = _supabase.auth.onAuthStateChange.listen((event) {
        _user = event.session?.user;
        notifyListeners();
      });
      
      // Delay artificial para a Splash Screen aparecer
      await Future.delayed(const Duration(milliseconds: 3500));
    } catch (e) {
      _errorMessage = 'Erro ao inicializar autenticação: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        // No Flutter Web, o redirectTo nulo faz com que redirecione para a mesma página atual.
        // No mobile, usamos o deeplink customizado.
        redirectTo: kIsWeb ? null : authCallbackUrl,
        scopes: 'email profile',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabase.auth.signOut();
      _user = null;
    } catch (e) {
      _errorMessage = 'Erro ao fazer logout: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        await _supabase.auth.refreshSession();
      }
    } catch (e) {
      _errorMessage = 'Erro ao renovar sessão: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

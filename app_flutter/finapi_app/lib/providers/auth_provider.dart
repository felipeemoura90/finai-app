import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:async'; // <-- NOVO: Necessário para o StreamSubscription
import '../core/app_config.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  User? _user;
  bool _isLoading = true;
  String? _errorMessage;

  // <-- NOVO: Variável para guardar a escuta de eventos do Supabase
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
      // Tenta recuperar sessão salva
      final sessionString = await _storage.read(key: 'session');
      if (sessionString != null) {
        try {
          // Tenta decodificar. Se o texto estiver quebrado, ele pula pro "catch"
          final sessionMap = jsonDecode(sessionString) as Map<String, dynamic>;
          final session = Session.fromJson(sessionMap);

          if (session != null) {
            _supabase.auth.setSession(session.accessToken);
            _user = session.user;
          }
        } catch (e) {
          // Se der o erro de formatação, simplesmente apaga a sujeira antiga
          await _storage.delete(key: 'session');
        }
      }

      // Escuta mudanças de estado de auth e guarda na variável _authSubscription
      _authSubscription = _supabase.auth.onAuthStateChange.listen((event) {
        _user = event.session?.user;
        _saveSession(event.session);
        notifyListeners();
      });
      await Future.delayed(const Duration(milliseconds: 3500));
    } catch (e) {
      _errorMessage = 'Erro ao inicializar autenticação: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveSession(Session? session) async {
    if (session != null) {
      await _storage.write(key: 'session', value: jsonEncode(session.toJson()));
    } else {
      await _storage.delete(key: 'session');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: authCallbackUrl,
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
      await _storage.delete(key: 'session');
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

  // <-- NOVO: Sobrescrevemos o dispose para limpar o listener e evitar Memory Leak
  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

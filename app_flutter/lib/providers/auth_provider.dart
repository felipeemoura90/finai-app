import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // Para o kIsWeb
import '../core/app_config.dart';
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = true;
  bool _hasTransactions = false;
  String? _errorMessage; // <-- Restabelecido

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get hasTransactions => _hasTransactions;
  String? get errorMessage => _errorMessage; // <-- Restabelecido

  String get userName => _user?.userMetadata?['full_name'] ?? 'Usuário';
  String get userEmail => _user?.email ?? '';
  String? get userPhoto => _user?.userMetadata?['avatar_url'];

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _user = Supabase.instance.client.auth.currentUser;
    if (_user != null) {
      await checkUserTransactions();
    }
    _isLoading = false;
    notifyListeners();

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;
      _errorMessage = "Auth Event: $event | User: ${session?.user?.id}";
      _user = session?.user;
      if (_user != null) {
        await checkUserTransactions();
      }
      notifyListeners();
    });
  }

  Future<void> checkUserTransactions() async {
    try {
      final data = await Supabase.instance.client
          .from('transactions')
          .select('id')
          .limit(1);
      _hasTransactions = data.isNotEmpty;
    } catch (e) {
      _hasTransactions = true;
    }
    notifyListeners();
  }

  // <-- FUNÇÃO DE LOGIN RESTABELECIDA PARA O LOGIN_SCREEN
  Future<void> signInWithGoogle() async {
    try {
      _errorMessage = null;
      notifyListeners();
      
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : authCallbackUrl,
      );
    } catch (e) {
      _errorMessage = "Erro ao fazer login com o Google: $e";
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
  }
}
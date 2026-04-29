# 🔐 Guia de Configuração: Supabase com Authentication Code Flow + PKCE

## 1️⃣ Configurar Supabase

### Passo 1: Criar projeto no Supabase
1. Acesse [https://supabase.com](https://supabase.com)
2. Faça login ou crie uma conta
3. Clique em "New Project"
4. Preencha os dados:
   - **Project Name**: `Felipe App` (ou nome que preferir)
   - **Database Password**: Anote em local seguro!
   - **Region**: Escolha a mais próxima (ex: South America - São Paulo)
5. Aguarde a criação (leva alguns minutos)

### Passo 2: Obter credenciais
1. Vá para **Settings** → **API**
2. Copie:
   - **Project URL** → Use como `SUPABASE_URL`
   - **Anon public key** → Use como `SUPABASE_ANON_KEY`

### Passo 3: Configurar OAuth com Google
1. No painel Supabase, vá para **Authentication** → **Providers**
2. Ative **Google**
3. Precisará de credenciais Google OAuth:
   - Acesse [Google Cloud Console](https://console.cloud.google.com)
   - Crie um novo projeto
   - Ative a API do Google+
   - Crie um "OAuth 2.0 Client ID" (tipo: Web application)
   - URIs autorizados:
     - `http://localhost:3000/callback`
     - `http://localhost:8080/callback`
     - `finapi://auth/callback` (para mobile)
   - Copie o Client ID e Secret para o Supabase

---

## 2️⃣ Configurar Backend (FastAPI)

### Passo 1: Atualizar `.env` em `api_python/`

```bash
# Arquivo: api_python/.env

# Chave da API do Google Gemini
GEMINI_API_KEY=sua_chave_aqui

# Configurações do Supabase (OBRIGATORIO!)
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_ANON_KEY=sua_anon_key_aqui

# JWT Secret (será gerado automaticamente se não definir)
JWT_SECRET=sua_chave_secreta_aqui
```

### Passo 2: Instalar dependências
```bash
cd api_python
pip install -r requirements.txt
```

### Passo 3: Iniciar servidor
```bash
cd api_python
$env:PYTHONPATH="."; python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

✅ Servidor deve estar em: **http://localhost:8000**

---

## 3️⃣ Configurar Frontend (Flutter)

### Passo 1: Atualizar Supabase Config

Edite: `app_flutter/finapi_app/lib/core/config/supabase_config.dart`

```dart
// Configurações do Supabase
const String supabaseUrl = 'https://seu-projeto.supabase.co';
const String supabaseAnonKey = 'sua_anon_key_aqui';

// URLs de callback
const String authCallbackUrl = 'finapi://auth/callback';

// Configurações de ambiente
const bool isProduction = bool.fromEnvironment('dart.vm.product');
```

### Passo 2: Executar Flutter (Web)
```bash
cd app_flutter/finapi_app
flutter run --web-port 3000
```

✅ App deve estar em: **http://localhost:3000**

### Passo 3: Testar Login
1. Clique em "Login com Google"
2. Selecione sua conta Google
3. Você deve ser redirecionado para o dashboard

---

## 4️⃣ Arquitetura de Autenticação

### Flow de Autenticação (Authorization Code + PKCE)

```
Frontend (Flutter)
    ↓
1. Gera code_verifier e code_challenge (PKCE)
2. Redireciona para Supabase Auth URL
    ↓
Supabase Google OAuth
    ↓
3. Usuário faz login com Google
4. Supabase redireciona com authorization code
    ↓
Backend (FastAPI)
    ↓
5. Exchange code + verifier por sessão
6. Gera JWT token
7. Retorna para Frontend
    ↓
Frontend
    ↓
8. Armazena token em secure storage
9. Usa token em requisições autenticadas
```

### Endpoints Disponíveis

#### 1. Gerar URL de Login
```bash
GET /auth/url?redirect_uri=http://localhost:3000/callback
```

Retorna:
```json
{
  "auth_url": "https://seu-projeto.supabase.co/auth/v1/authorize?...",
  "code_verifier": "xxxxx"
}
```

#### 2. Fazer Callback após Google Login
```bash
POST /auth/callback
Body: {
  "code": "codigo_do_google",
  "code_verifier": "verifier_do_pkce",
  "redirect_uri": "http://localhost:3000/callback"
}
```

#### 3. Renovar Token
```bash
POST /auth/refresh
Body: {
  "refresh_token": "seu_refresh_token"
}
```

#### 4. Obter Dados do Usuário
```bash
GET /auth/me
Headers: {
  "Authorization": "Bearer seu_access_token"
}
```

#### 5. Fazer Logout
```bash
POST /auth/logout
Headers: {
  "Authorization": "Bearer seu_access_token"
}
```

---

## 5️⃣ Estrutura de Pastas

```
Felipe_app/
├── api_python/
│   ├── main.py                    # FastAPI app
│   ├── requirements.txt           # Dependências Python
│   ├── .env                       # Configurações (NÃO commitar!)
│   ├── services/
│   │   ├── auth_service.py       # Lógica de autenticação
│   │   ├── auth_middleware.py    # Middleware JWT
│   │   └── ...
│   └── routers/
│       ├── auth_api.py           # Endpoints de auth
│       └── ...
│
└── app_flutter/finapi_app/
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart
    │   ├── core/
    │   │   ├── config/
    │   │   │   └── supabase_config.dart  # ← Configurar aqui!
    │   │   └── theme/
    │   │       └── app_colors.dart
    │   ├── providers/
    │   │   └── auth_provider.dart       # State management
    │   ├── screens/
    │   │   ├── login_screen.dart
    │   │   ├── dashboard_screen.dart
    │   │   └── ...
    │   └── widgets/
    │       ├── auth_guard.dart          # Proteção de rotas
    │       └── ...
```

---

## 6️⃣ Segurança - Checklist

- [ ] `JWT_SECRET` é uma string aleatória forte
- [ ] `.env` está no `.gitignore` (não commitado)
- [ ] CORS está configurado apenas para domínios permitidos
- [ ] PKCE está sendo usado (não é apenas Authorization Code)
- [ ] Tokens são armazenados em secure storage (Flutter)
- [ ] Access token tem expiração curta (15 min)
- [ ] Refresh token tem expiração longa (30 dias)
- [ ] Revogação de token funciona no logout

---

## 7️⃣ Troubleshooting

### ❌ "SUPABASE_URL não encontrado"
**Solução**: Verifique se `.env` existe em `api_python/` com as variáveis corretas

### ❌ "Port 8080 already in use"
**Solução**: Use outra porta: `flutter run --web-port 3000`

### ❌ "Failed to compile application"
**Solução**: 
```bash
flutter clean
flutter pub get
flutter run --web-port 3000
```

### ❌ "Module named 'supabase' not found"
**Solução**: 
```bash
cd api_python
pip install -r requirements.txt
```

### ❌ "Invalid OAuth redirect URI"
**Solução**: Certifique-se que a URI registrada no Google Cloud Console e Supabase bate com a que seu app está usando

---

## ✅ Teste Completo

1. **Backend rodando**: `curl http://localhost:8000/docs`
2. **Frontend rodando**: Abra `http://localhost:3000` no navegador
3. **Clique em Login**
4. **Selecione sua conta Google**
5. **Verifique se foi redirecionado para o dashboard**

🎉 Se chegou aqui, **autenticação está funcionando!**

---

## 📞 Suporte

Se enfrentar problemas:
1. Verifique os logs no terminal
2. Abra DevTools do navegador (F12)
3. Verifique Network tab para requests falhando
4. Verifique console para erros JavaScript

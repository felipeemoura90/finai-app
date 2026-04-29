# Sistema de Autenticação Supabase

Este projeto agora inclui um sistema completo de autenticação usando Supabase com Authorization Code Flow e PKCE.

## 🚀 Configuração

### 1. Backend (Python/FastAPI)

#### Variáveis de Ambiente

Adicione ao arquivo `api_python/.env`:

```env
# Configurações do Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key

# JWT Secret (opcional - será gerado automaticamente se não definido)
JWT_SECRET=your_jwt_secret_key
```

#### Como obter as chaves do Supabase:

1. Acesse [https://supabase.com](https://supabase.com)
2. Crie um novo projeto
3. Vá para Settings > API
4. Copie a URL do projeto e a anon key

### 2. Frontend (Flutter)

#### Variáveis de Ambiente

Adicione ao comando de build ou ao arquivo de configuração:

```bash
flutter build web --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your_supabase_anon_key
```

Ou crie um arquivo `.env` na raiz do projeto Flutter e use um package como `flutter_dotenv`.

#### Configuração do OAuth

No painel do Supabase:

1. Vá para Authentication > Providers
2. Ative o Google OAuth
3. Configure as credenciais do Google Console
4. Adicione as URLs de redirect:
   - `finapi://auth/callback` (para mobile)
   - `http://localhost:8080/auth/callback` (para web)

## 📁 Estrutura dos Arquivos

### Backend
```
api_python/
├── services/
│   ├── auth_service.py          # Serviço de autenticação Supabase
│   └── auth_middleware.py       # Middleware de proteção de rotas
├── routers/
│   └── auth_api.py              # Rotas de autenticação
└── .env                         # Configurações
```

### Frontend
```
app_flutter/finapi_app/
├── providers/
│   └── auth_provider.dart       # Provider de estado de autenticação
├── screens/
│   └── login_screen.dart        # Tela de login
├── widgets/
│   └── auth_guard.dart          # Guard para rotas protegidas
├── core/config/
│   └── supabase_config.dart     # Configurações do Supabase
└── main.dart                    # App principal com autenticação
```

## 🔐 Funcionalidades

### Backend
- ✅ Authorization Code Flow com PKCE
- ✅ Geração e validação de tokens JWT
- ✅ Refresh token automático
- ✅ Middleware de proteção de rotas
- ✅ Integração completa com Supabase Auth

### Frontend
- ✅ Tela de login com Google OAuth
- ✅ Gerenciamento de estado de autenticação
- ✅ Persistência de sessão com secure storage
- ✅ Guards para rotas protegidas
- ✅ Logout com confirmação

## 🛠️ Como Usar

### 1. Instalar Dependências

```bash
# Backend
cd api_python
pip install -r requirements.txt

# Frontend
cd app_flutter/finapi_app
flutter pub get
```

### 2. Configurar Variáveis de Ambiente

Configure as variáveis de ambiente conforme descrito acima.

### 3. Executar

```bash
# Backend
cd api_python
python main.py

# Frontend
cd app_flutter/finapi_app
flutter run --web-port 8080
```

### 4. Testar Autenticação

1. Abra o app Flutter
2. Clique em "Continuar com Google"
3. Faça login com sua conta Google
4. Você será redirecionado para o dashboard

## 🔒 Segurança

- **PKCE**: Protege contra ataques de interceptação de código
- **JWT Stateless**: Tokens seguros e verificáveis
- **Secure Storage**: Sessões persistidas de forma segura
- **CORS**: Controle de origens permitidas
- **Refresh Tokens**: Renovação automática de sessões

## 📚 APIs Disponíveis

### Autenticação
- `GET /auth/url` - Gera URL de autenticação
- `POST /auth/callback` - Troca código por tokens
- `POST /auth/refresh` - Renova tokens
- `GET /auth/me` - Informações do usuário atual
- `POST /auth/logout` - Logout

### Rotas Protegidas
Todas as rotas da API financeira agora requerem autenticação:

```python
from services.auth_middleware import get_current_user

@app.get("/api/dashboard")
def get_dashboard(current_user: dict = Depends(get_current_user)):
    # Rota protegida
    pass
```

## 🐛 Troubleshooting

### Erro: "SUPABASE_URL e SUPABASE_ANON_KEY são obrigatórios"
- Verifique se as variáveis de ambiente estão configuradas no `.env`

### Erro: "Invalid login credentials"
- Verifique se o OAuth do Google está configurado no Supabase
- Confirme se as URLs de redirect estão corretas

### Erro: "Token inválido ou expirado"
- O token JWT pode ter expirado (15 minutos por padrão)
- Use o refresh token para renovar a sessão

## 📝 Notas de Desenvolvimento

- O sistema usa Authorization Code Flow com PKCE para máxima segurança
- Tokens são armazenados de forma segura usando flutter_secure_storage
- A autenticação é stateless no backend usando JWT
- O frontend gerencia o estado de autenticação com Provider

## 🔄 Próximos Passos

- [ ] Configurar OAuth providers adicionais (GitHub, Apple, etc.)
- [ ] Implementar recuperação de senha
- [ ] Adicionar perfis de usuário customizados
- [ ] Implementar roles e permissões
- [ ] Adicionar autenticação multifator (2FA)
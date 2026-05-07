# FinAI - Assistente Financeiro Inteligente
O FinAI é uma plataforma moderna de gestão financeira que combina o poder da Inteligência Artificial com uma interface intuitiva e responsiva. O sistema permite que usuários importem extratos bancários (OFX), categorizem transações automaticamente via IA e recebam insights financeiros personalizados em tempo real.

🚀 Tecnologias Utilizadas
Frontend (Mobile & Web)
Flutter: Framework para desenvolvimento multiplataforma.

Provider: Gerenciamento de estado centralizado e eficiente.

Dio: Cliente HTTP avançado com suporte a interceptores para autenticação automática.

File Selector: Integração nativa para seleção de arquivos em ambiente Web.

Fl Chart: Renderização de gráficos financeiros dinâmicos.

Backend (API)
FastAPI (Python): Framework de alta performance para a construção da API.

Supabase (PostgreSQL): Banco de dados relacional com políticas de segurança RLS (Row Level Security).

Celery & Redis: Processamento assíncrono em background para tarefas pesadas, como o parsing de arquivos OFX.

Groq (Llama 3.3) & Google Gemini: Motores de IA integrados para categorização de gastos e chat interativo.

✨ Funcionalidades Principais
1. Gestão Inteligente com IA
Categorização Automática: A IA analisa as descrições dos extratos e atribui categorias, ícones e nomes amigáveis às transações.

FinChat: Assistente virtual integrado para tirar dúvidas sobre suas finanças, utilizando modelos de linguagem avançados (fallback automático entre Llama 3.3 e Gemini).

Insights Preditivos: Projeções de gastos mensais baseadas no seu histórico de consumo.

2. Interface Responsiva e Adaptável
Design Inteligente: O app detecta o dispositivo e adapta a navegação:

Desktop/Web: Sidebar fixa para navegação otimizada em telas largas.

Mobile: Navegação via Bottom Bar e menus de ação via Bottom Sheet para fácil uso com uma mão.

Integração Google: Login simplificado com exibição dinâmica de nome, e-mail e foto de perfil do usuário.

3. Performance e Segurança
Sistema de Cache Inteligente: Implementação de decoradores customizados no backend para acelerar o carregamento de Dashboards e Feeds.

Processamento em Background: Importação de arquivos OFX realizada de forma assíncrona, permitindo que o usuário continue navegando enquanto os dados são processados.

Segurança RLS: Proteção de dados a nível de banco de dados, garantindo que cada usuário acesse exclusivamente suas próprias informações.

🛠️ Melhorias de Arquitetura Implementadas
Recentemente, o projeto passou por uma refatoração profunda para garantir escalabilidade:

Separação de Responsabilidades (SoC): Lógicas de negócio foram movidas de componentes visuais para serviços dedicados (ai_service.py, AuthProvider, etc.).

Networking Profissional: Implementação de interceptores no Flutter que anexam tokens de autenticação automaticamente em todas as chamadas de API.

Tratamento de Erros Resiliente: Sistema de fallback para imagens de perfil (tratando erros 429 e CORS) e tratamento de exceções em fluxos de upload.

Código DRY (Don't Repeat Yourself): Centralização da lógica de cache e de comunicação com IA para facilitar futuras manutenções.

⚙️ Como Configurar
Backend:

Configure as chaves no arquivo .env (Supabase, Groq, Gemini).

Inicie o Worker do Celery para processamento de arquivos.

Rode a API com uvicorn main:app.

Frontend:

Configure a URL da API no arquivo app_config.dart.

Certifique-se de que o Supabase está configurado para permitir a URL de redirecionamento do seu ambiente Web/Mobile.

Execute flutter run -d web-server --web-port 3000.
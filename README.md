# FinAI - Inteligência Artificial Financeira

## 🚀 Funcionalidades

- **Categorização automática**: IA categoriza transações desconhecidas
- **Insights personalizados**: Análises inteligentes dos seus gastos
- **Dashboard completo**: Ganhos, gastos e saldo real
- **Feed inteligente**: Transações categorizadas automaticamente

## 🤖 Configuração da IA (Gemini)

### 1. Obter Chave da API

1. Acesse [Google AI Studio](https://aistudio.google.com/)
2. Faça login com sua conta Google
3. Vá em "Get API key" no menu lateral
4. Crie uma nova chave ou use uma existente

### 2. Configurar no Projeto

1. Copie o arquivo `.env.example` para `.env`:
   ```bash
   cp .env.example .env
   ```

2. Edite o arquivo `.env` e adicione sua chave:
   ```
   GEMINI_API_KEY=sua_chave_aqui
   ```

### 3. Instalar Dependências

```bash
pip install -r requirements.txt
```

## 🏃‍♂️ Como Executar

### Backend (Python)
```bash
cd api_python
python main.py
```

### Frontend (Flutter Web)
```bash
cd app_flutter
flutter run -d web-server --web-port=8080
```

Acesse: http://localhost:8080

## 📊 Funcionalidades da IA

### Categorização Automática
- Transações desconhecidas são automaticamente categorizadas
- Regras são salvas no banco para aprendizado contínuo
- Badge "IA" indica transações categorizadas pela inteligência artificial

### Insights Personalizados
- Análise mensal dos seus dados financeiros
- Dicas específicas baseadas nos seus padrões de gasto
- Sugestões práticas para o próximo mês

## 🔧 Tecnologias

- **Backend**: Python + FastAPI
- **IA**: Google Gemini 1.5 Flash
- **Frontend**: Flutter Web
- **Banco**: SQLite (regras de categorização)
- **Dados**: Arquivo OFX de extratos bancários

## 📝 Exemplo de Insight IA

"Felipe, seus gastos com Mercado subiram 15% este mês. Recomendo planejar melhor as compras semanais para economizar R$ 200 na próxima quinzena."
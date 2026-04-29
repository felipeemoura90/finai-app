from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import finance_api, auth_api # Importa as rotas criadas

# 1. Inicializa o "Servidor"
app = FastAPI(title="FinAI API Engine")

# 2. Configuração de Segurança (CORS)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 3. Conecta as rotas modulares
app.include_router(finance_api.router)
app.include_router(auth_api.router)

# Fim! O uvicorn vai rodar este arquivo.
from fastapi import APIRouter
from services.ofx_service import OfxService
from pydantic import BaseModel
from fastapi import APIRouter, UploadFile, File
import shutil
import os

class NovaRegra(BaseModel):
    keyword: str
    name: str
    categoria: str
    icon: str

# Inicializa o Router (Agrupador de URLs)
router = APIRouter(prefix="/api")

# Inicializa o serviço que lê o OFX
ofx_engine = OfxService()

# Adicionamos o meta_mensal como parâmetro, com 3000 de valor padrão
@router.get("/dashboard")
def get_dashboard_data(mes: str = "2026-04", meta_mensal: float = 3000.00):
    resumo = ofx_engine.obter_resumo_dashboard(mes, meta_mensal)
    
    ganhos = resumo["ganhos"]
    gastos = resumo["gastos"]
    saldo = resumo["saldo"]
    meta = meta_mensal # Agora a meta vem do Flutter!
    
    projecao_ia = gastos * 1.15 
    sobra_prevista = meta - projecao_ia
    
    return {
        "status": "success",
        "data": {
            "ganhos": ganhos,
            "gastos": gastos,
            "saldo": saldo,
            "meta": meta,
            "projecao_ia": projecao_ia,
            "insight_ia": resumo.get("insight_ia", f"Seu histórico aponta uma sobra de R$ {sobra_prevista:.2f} neste mês. Atenção aos gastos com {resumo['categorias'][0]['nome'] if resumo['categorias'] else 'diversos'}!"),
            "categorias": resumo["categorias"]
        }
    }

@router.get("/feed")
def get_feed(mes: str = "2026-04"):
    # Chama a função blindada que criamos acima
    dados_feed = ofx_engine.obter_extrato_feed(mes)
    
    return {
        "status": "success",
        "data": dados_feed # Agora isso é garantido de ser uma lista [ ... ]
    }

@router.get("/settings")
def get_settings_params():
    # Mantido estático por enquanto
    return {
        "status": "success",
        "data": {
            "auto_adjust": True,
            "limits": {
                "fixo": {"percentage": 0.50, "value": 2600.00},
                "variavel": {"percentage": 0.30, "value": 1560.00},
                "investimento": {"percentage": 0.20, "value": 1040.00}
            }
        }
    }
@router.get("/fluxo")
def get_fluxo_caixa(mes: str = "2026-04"):
    dados_diarios = ofx_engine.obter_fluxo_diario(mes)
    return {
        "status": "success",
        "data": dados_diarios
    }
@router.post("/regras")
def salvar_nova_regra(regra: NovaRegra):
    # Envia a nova regra para o nosso serviço SQLite
    ofx_engine.cleaner.salvar_regra(
        keyword=regra.keyword,
        name=regra.name,
        categoria=regra.categoria,
        icon=regra.icon
    )
    return {"status": "success", "message": "Regra salva com sucesso!"}

@router.post("/upload")
async def upload_arquivo(file: UploadFile = File(...)):
    # 1. Garante que a pasta data existe
    os.makedirs("data", exist_ok=True)
    
    # 2. Salva o arquivo fisicamente na máquina
    caminho_destino = f"data/{file.filename}"
    with open(caminho_destino, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # 3. Manda o serviço ler esse arquivo novo!
    ofx_engine.atualizar_arquivo(caminho_destino)
    
    return {"status": "success", "message": f"{file.filename} importado e processado!"}
from pathlib import Path
from fastapi import APIRouter, HTTPException, UploadFile, File, BackgroundTasks, Depends, Request
from pydantic import BaseModel
from services.ofx_service import OfxService
from services.auth_middleware import get_current_user # Importe o verificador
from services.supabase_service import SupabaseService
from services.ai_service import AIService
from services.clearing_service import ClearingService
from config import settings
from services.cache_service import CacheService
from celery_worker import processar_extrato_task

class NovaRegra(BaseModel):
    keyword: str
    name: str
    categoria: str
    icon: str

# Inicializa o Router (Agrupador de URLs)
router = APIRouter(
    prefix="/api", 
    tags=["finance"],
    dependencies=[Depends(get_current_user)] # TRANCANDO AS ROTAS!
)

# Inicializa o serviço que lê o OFX
ofx_engine = OfxService()
supabase_db = SupabaseService()
ai_brain = AIService()
cleaner = ClearingService()
cache_engine = CacheService()

@router.get("/dashboard")
def get_dashboard_data(
    mes: str = settings.DEFAULT_MONTH, 
    meta_mensal: float = settings.DEFAULT_META,
    current_user: dict = Depends(get_current_user)
):
    user_id = current_user['id']
    # Cria uma chave única para esse usuário, mês e meta
    cache_key = f"user:{user_id}:dashboard:{mes}:{meta_mensal}"
    
    # 1. TENTA PEGAR DO CACHE
    cached_data = cache_engine.get(cache_key)
    if cached_data:
        print(f"[CACHE HIT] Dashboard carregado da memória para {user_id}")
        return cached_data

    # 2. SE NÃO TEM CACHE, FAZ O TRABALHO PESADO
    transacoes = supabase_db.get_user_transactions(user_id, mes, current_user['token'])
    ofx_engine.injetar_transacoes(transacoes)
    resumo = ofx_engine.obter_resumo_dashboard(mes, meta_mensal)
    
    ganhos = resumo["ganhos"]
    gastos = resumo["gastos"]
    saldo = resumo["saldo"]
    meta = meta_mensal
    projecao_ia = gastos * 1.15 
    sobra_prevista = meta - projecao_ia
    
    resposta = {
        "status": "success",
        "data": {
            "ganhos": ganhos,
            "gastos": gastos,
            "saldo": saldo,
            "meta": meta,
            "projecao_ia": projecao_ia,
            "insight_ia": resumo.get("insight_ia", f"Seu histórico aponta uma sobra de R$ {sobra_prevista:.2f} neste mês."),
            "categorias": resumo["categorias"]
        }
    }
    
    # 3. SALVA O RESULTADO NO CACHE PARA A PRÓXIMA VEZ (Expira em 2 horas)
    cache_engine.set(cache_key, resposta, expire_seconds=7200)
    
    return resposta

@router.get("/feed")
def get_feed(
    mes: str = settings.DEFAULT_MONTH,
    current_user: dict = Depends(get_current_user)
):
    user_id = current_user['id']
    # Cria uma chave única para esse usuário, mês e meta
    cache_key = f"user:{user_id}:feed:{mes}"
    
    # 1. TENTA PEGAR DO CACHE
    cached_data = cache_engine.get(cache_key)
    if cached_data:
        print(f"[CACHE HIT] Feed carregado da memória para {user_id}")
        return cached_data

    # 2. SE NÃO TEM CACHE, FAZ O TRABALHO PESADO
    transacoes = supabase_db.get_user_transactions(user_id, mes, current_user['token'])
    ofx_engine.injetar_transacoes(transacoes)
    
    # Chama a função blindada que criamos acima
    dados_feed = ofx_engine.obter_extrato_feed(mes)
    
    resposta = {
        "status": "success",
        "data": dados_feed # Agora isso é garantido de ser uma lista [ ... ]
    }   

    # 3. SALVA O RESULTADO NO CACHE PARA A PRÓXIMA VEZ (Expira em 2 horas)
    cache_engine.set(cache_key, resposta, expire_seconds=7200)
    
    return resposta

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
def get_fluxo_caixa(
    mes: str = settings.DEFAULT_MONTH,
    current_user: dict = Depends(get_current_user)
):
    user_id = current_user['id']
    cache_key = f"user:{user_id}:fluxo:{mes}"
    
    # 1. TENTA PEGAR DO CACHE
    cached_data = cache_engine.get(cache_key)
    if cached_data:
        print(f"[CACHE HIT] Fluxo carregado da memória para {user_id}")
        return cached_data

    # 2. SE NÃO TEM CACHE, BUSCA DO BANCO E PROCESSA
    # O current_user['token'] garante que o Supabase libere os dados!
    transacoes = supabase_db.get_user_transactions(user_id, mes, current_user['token'])
    ofx_engine.injetar_transacoes(transacoes)
    
    dados_diarios = ofx_engine.obter_fluxo_diario(mes)
    
    resposta = {
        "status": "success",
        "data": dados_diarios
    }
    
    # 3. SALVA NO CACHE PARA A PRÓXIMA (Expira em 2 horas = 7200 seg)
    cache_engine.set(cache_key, resposta, expire_seconds=7200)
    
    return resposta

@router.post("/regras")
def salvar_nova_regra(
    regra: NovaRegra,
    current_user: dict = Depends(get_current_user) # <-- ADICIONADO AQUI
):
    # Envia a nova regra para o Supabase
    ofx_engine.cleaner.salvar_regra(
        user_id=current_user['id'],
        keyword=regra.keyword,
        name=regra.name,
        categoria=regra.categoria,
        icon=regra.icon
    )
    
    # ---> O PULO DO GATO (INVALIDAÇÃO DE CACHE) <---
    # Limpa a memória do usuário logado. Assim, quando ele voltar para a 
    # aba Feed ou Dashboard, os dados serão recategorizados usando a regra nova!
    cache_engine.invalidate_user_cache(current_user['id'])

    return {"status": "success", "message": "Regra salva com sucesso!"}

# Função isolada que fará o trabalho pesado sem travar a API
def processar_extrato_background(caminho_arquivo: str):
    try:
        ofx_engine.atualizar_arquivo(caminho_arquivo)
        print(f"[BACKGROUND] Arquivo {caminho_arquivo} processado com sucesso!")
    except Exception as e:
        print(f"[BACKGROUND ERRO] Falha ao processar {caminho_arquivo}: {e}")

@router.post("/upload")
async def upload_arquivo(
    request: Request,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    try:
        print(f"[UPLOAD] Arquivo recebido: {file.filename} do usuario {current_user.get('email')}")
        conteudo_bytes = await file.read()

        # Decodifica o arquivo para texto simples para viajar até o Celery via JSON
        try:
            texto = conteudo_bytes.decode('utf-8')
        except UnicodeDecodeError:
            texto = conteudo_bytes.decode('latin-1')

        # Extrai o Token para dar permissão ao Celery de salvar os dados
        auth_header = request.headers.get('Authorization')
        token = auth_header.replace('Bearer ', '') if auth_header else ""

        # ---> A MÁGICA DA FILA AQUI <---
        # Ao invés de travar a API rodando a função, enviamos com .delay()
        processar_extrato_task.delay(texto, current_user['id'], token)

        # O FastAPI responde para o aplicativo Flutter instantaneamente!
        return {
            "status": "success", 
            "message": "Arquivo na fila! A IA está processando suas transações em segundo plano."
        }

    except Exception as e:
        print(f"[UPLOAD ERROR] {type(e).__name__}: {e}")
        raise HTTPException(status_code=500, detail=f"Falha ao receber o arquivo: {e}")
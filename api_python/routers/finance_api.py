from pathlib import Path
from functools import wraps # Importante para o Decorator
from fastapi import APIRouter, HTTPException, UploadFile, File, BackgroundTasks, Depends, Request
from pydantic import BaseModel
from services.ofx_service import OfxService
from services.auth_middleware import get_current_user
from services.supabase_service import SupabaseService
from services.ai_service import AIService
from services.clearing_service import ClearingService
from config import settings
from services.cache_service import CacheService
from celery_worker import processar_extrato_task
from services.pluggy_service import PluggyService

class NovaRegra(BaseModel):
    keyword: str
    name: str
    categoria: str
    icon: str

class ChatRequest(BaseModel):
    message: str

class SyncRequest(BaseModel):
    item_id: str

router = APIRouter(
    prefix="/api", 
    tags=["finance"],
    dependencies=[Depends(get_current_user)]
)

ofx_engine = OfxService()
supabase_db = SupabaseService()
ai_brain = AIService()
cleaner = ClearingService()
cache_engine = CacheService()
pluggy_service = PluggyService()

# ==========================================
# DECORADOR MÁGICO DE CACHE
# ==========================================
def cache_endpoint(prefix: str, expire_seconds: int = 7200):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Extrai o utilizador atual das dependências do FastAPI
            current_user = kwargs.get('current_user')
            if not current_user:
                return func(*args, **kwargs)
            
            user_id = current_user['id']
            
            # Constrói a chave dinâmica ignorando parâmetros não "cacheados"
            partes_chave = [f"user:{user_id}:{prefix}"]
            for key, value in kwargs.items():
                if key not in ('current_user', 'request', 'file'):
                    partes_chave.append(str(value))
                    
            cache_key = ":".join(partes_chave)
            
            # 1. TENTA LER DO CACHE
            cached_data = cache_engine.get(cache_key)
            if cached_data:
                print(f"[CACHE HIT] {prefix.capitalize()} carregado da memória para {user_id}")
                return cached_data

            # 2. SEM CACHE: EXECUTA A FUNÇÃO (TRABALHO PESADO)
            resultado = func(*args, **kwargs)
            
            # 3. GUARDA O RESULTADO NO CACHE
            cache_engine.set(cache_key, resultado, expire_seconds=expire_seconds)
            return resultado
        return wrapper
    return decorator


# ==========================================
# ROTAS LIMPAS E REFATORADAS
# ==========================================

@router.get("/dashboard")
@cache_endpoint(prefix="dashboard") # <-- Uso do Decorador
def get_dashboard_data(
    mes: str = settings.DEFAULT_MONTH, 
    meta_mensal: float = settings.DEFAULT_META,
    current_user: dict = Depends(get_current_user)
):
    user_id = current_user['id']
    transacoes = supabase_db.get_user_transactions(user_id, mes, current_user['token'])
    ofx_engine.injetar_transacoes(transacoes)
    resumo = ofx_engine.obter_resumo_dashboard(mes, meta_mensal)
    
    gastos = resumo["gastos"]
    projecao_ia = gastos * 1.15 
    sobra_prevista = meta_mensal - projecao_ia
    
    return {
        "status": "success",
        "data": {
            "ganhos": resumo["ganhos"],
            "gastos": gastos,
            "saldo": resumo["saldo"],
            "meta": meta_mensal,
            "projecao_ia": projecao_ia,
            "insight_ia": resumo.get("insight_ia", f"O seu histórico aponta para uma sobra de R$ {sobra_prevista:.2f} neste mês."),
            "categorias": resumo["categorias"]
        }
    }

@router.get("/feed")
@cache_endpoint(prefix="feed") # <-- Uso do Decorador
def get_feed(
    mes: str = settings.DEFAULT_MONTH,
    current_user: dict = Depends(get_current_user)
):
    user_id = current_user['id']
    transacoes = supabase_db.get_user_transactions(user_id, mes, current_user['token'])
    ofx_engine.injetar_transacoes(transacoes)
    
    return {
        "status": "success",
        "data": ofx_engine.obter_extrato_feed(mes)
    }

@router.get("/fluxo")
@cache_endpoint(prefix="fluxo") # <-- Uso do Decorador
def get_fluxo_caixa(
    mes: str = settings.DEFAULT_MONTH,
    current_user: dict = Depends(get_current_user)
):
    user_id = current_user['id']
    transacoes = supabase_db.get_user_transactions(user_id, mes, current_user['token'])
    ofx_engine.injetar_transacoes(transacoes)
    
    return {
        "status": "success",
        "data": ofx_engine.obter_fluxo_diario(mes)
    }

@router.post("/regras")
def salvar_nova_regra(
    regra: NovaRegra,
    current_user: dict = Depends(get_current_user)
):
    ofx_engine.cleaner.salvar_regra(
        user_id=current_user['id'],
        keyword=regra.keyword,
        name=regra.name,
        categoria=regra.categoria,
        icon=regra.icon
    )
    # Invalidação do Cache mantida
    cache_engine.invalidate_user_cache(current_user['id'])
    return {"status": "success", "message": "Regra salva com sucesso!"}

@router.post("/upload")
async def upload_arquivo(
    request: Request,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    try:
        print(f"[UPLOAD] Ficheiro recebido: {file.filename} do utilizador {current_user.get('email')}")
        conteudo_bytes = await file.read()

        try:
            texto = conteudo_bytes.decode('utf-8')
        except UnicodeDecodeError:
            texto = conteudo_bytes.decode('latin-1')

        auth_header = request.headers.get('Authorization')
        token = auth_header.replace('Bearer ', '') if auth_header else ""

        # Envia para a fila do Celery
        processar_extrato_task.delay(texto, current_user['id'], token)

        return {
            "status": "success", 
            "message": "Ficheiro na fila! A IA está a processar as suas transações em segundo plano."
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Falha ao receber o ficheiro: {e}")

@router.post("/chat")
async def chat_finai(
    request: ChatRequest,
    current_user: dict = Depends(get_current_user) # Mantemos por segurança de rota
):
    try:
        # A lógica caótica foi toda movida para a classe AIService!
        resposta = ai_brain.obter_resposta_chat(request.message)
        return {
            "status": "success",
            "data": {
                "response": resposta
            }
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

@router.get("/settings")
def get_settings_params():
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

@router.get("/pluggy/connect-token")
def get_pluggy_connect_token(current_user: dict = Depends(get_current_user)):
    """Gera um token de curta duração para abrir o Pluggy Connect Widget no app."""
    try:
        token = pluggy_service.get_connect_token()
        return {"status": "success", "connect_token": token}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/pluggy/sync")

async def sync_pluggy_account(
    request: SyncRequest, 
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user)
):
    user_id = current_user.get("id")
    access_token = current_user.get("token") # Necessário para o RLS do Supabase
    
    try:
        # Envia o processo demorado para o fundo
        background_tasks.add_task(
            pluggy_service.fetch_and_sync_transactions,
            request.item_id,
            user_id,
            access_token
        )
        return {"status": "processing", "message": "Sincronização iniciada em segundo plano."}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
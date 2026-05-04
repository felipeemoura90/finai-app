from pathlib import Path
from fastapi import APIRouter, HTTPException, UploadFile, File, BackgroundTasks, Depends, Request
from pydantic import BaseModel
from services.ofx_service import OfxService
from services.auth_middleware import get_current_user # Importe o verificador
from services.supabase_service import SupabaseService
from services.ai_service import AIService
from services.clearing_service import ClearingService
from config import settings

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

# Adicionamos o meta_mensal como parâmetro, com 3000 de valor padrão
@router.get("/dashboard")
def get_dashboard_data(
    mes: str = settings.DEFAULT_MONTH, 
    meta_mensal: float = settings.DEFAULT_META,
    current_user: dict = Depends(get_current_user)
):
    # Puxa do Supabase e injeta no motor Pandas
    transacoes = supabase_db.get_user_transactions(current_user['id'], mes, current_user['token'])
    ofx_engine.injetar_transacoes(transacoes)
    
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
def get_feed(
    mes: str = settings.DEFAULT_MONTH,
    current_user: dict = Depends(get_current_user)
):
    transacoes = supabase_db.get_user_transactions(current_user['id'], mes, current_user['token'])
    ofx_engine.injetar_transacoes(transacoes)
    
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
def get_fluxo_caixa(
    mes: str = settings.DEFAULT_MONTH,
    current_user: dict = Depends(get_current_user)
):
    # Verifique se o current_user['token'] foi adicionado aqui no finalzinho:
    transacoes = supabase_db.get_user_transactions(current_user['id'], mes, current_user['token'])
    
    ofx_engine.injetar_transacoes(transacoes)
    dados_diarios = ofx_engine.obter_fluxo_diario(mes)
    return {
        "status": "success",
        "data": dados_diarios
    }
@router.post("/regras")
def salvar_nova_regra(regra: NovaRegra):
    # Envia a nova regra para o Supabase
    ofx_engine.cleaner.salvar_regra(
        keyword=regra.keyword,
        name=regra.name,
        categoria=regra.categoria,
        icon=regra.icon
    )
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
        print(f"[UPLOAD] Tamanho do arquivo: {len(conteudo_bytes)} bytes")

        # Tenta decodificar o texto
        try:
            texto = conteudo_bytes.decode('utf-8')
        except:
            texto = conteudo_bytes.decode('latin-1')

        # Usa IA para ler o arquivo (Groq primeiro, Gemini como fallback)
        print("[UPLOAD] Enviando para a IA ler o extrato...")
        transacoes_brutas = ai_brain.extrair_transacoes_do_arquivo(texto)
        
        if not transacoes_brutas:
            print("[UPLOAD] Nenhuma transacao extraida!")
            raise HTTPException(
                status_code=400, 
                detail="Nao foi possivel ler as transacoes deste arquivo. Verifique o formato."
            )

        print(f"[UPLOAD] {len(transacoes_brutas)} transacoes extraidas. Formatando para o Supabase...")

        # Formata para o Supabase
        transacoes_prontas = []
        for t in transacoes_brutas:
            dados_limpos = cleaner.limpar_transacao(t['descricao'])
            
            transacoes_prontas.append({
                "user_id": current_user['id'],
                "data": t['data'] + "T12:00:00Z",
                "descricao": dados_limpos['name'],
                "valor": float(t['valor']),
                "categoria": dados_limpos['categoria'],
                "icon": dados_limpos['icon'],
                "raw_data": t['descricao']
            })

        # Insere no Supabase
        auth_header = request.headers.get('Authorization')
        token = auth_header.replace('Bearer ', '') if auth_header else ""
        
        print(f"[UPLOAD] Inserindo {len(transacoes_prontas)} transacoes no Supabase...")
        supabase_db.insert_transactions_for_user(token, transacoes_prontas)

        print("[UPLOAD] Concluido com sucesso!")
        return {
            "status": "success", 
            "message": f"{len(transacoes_prontas)} transacoes processadas e salvas."
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"[UPLOAD ERROR] {type(e).__name__}: {e}")
        raise HTTPException(status_code=500, detail=f"Falha ao processar o arquivo: {e}")
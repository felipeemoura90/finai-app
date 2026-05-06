import json
from celery import Celery
from config import settings
from services.ai_service import AIService
from services.clearing_service import ClearingService
from services.supabase_service import SupabaseService
from services.cache_service import CacheService

# Configuração do Celery conectando ao nosso Redis
redis_url = getattr(settings, 'REDIS_URL', 'redis://localhost:6379/0')

celery_app = Celery(
    "finai_tasks",
    broker=redis_url,
    backend=redis_url
)

celery_app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='America/Sao_Paulo',
    enable_utc=True,
)

# Inicializa os "motores" que o Celery vai precisar para trabalhar sozinho
ai_brain = AIService()
cleaner = ClearingService()
supabase_db = SupabaseService()
cache_engine = CacheService()

@celery_app.task
def processar_extrato_task(texto_bruto: str, user_id: str, token: str):
    """Tarefa assíncrona que roda em segundo plano lendo o extrato e salvando no banco"""
    try:
        print(f"[CELERY] Iniciando processamento para o usuario {user_id}...")
        
        transacoes_brutas = ai_brain.extrair_transacoes_do_arquivo(texto_bruto)
        
        if not transacoes_brutas:
            print("[CELERY] Nenhuma transacao extraida.")
            return {"status": "error", "message": "Nenhuma transação encontrada"}

        # NOVO: Carrega as regras ESPECÍFICAS deste usuário via REST antes de iniciar o loop
        regras_usuario = cleaner.carregar_regras_usuario(user_id, token)

        transacoes_prontas = []
        for t in transacoes_brutas:
            # Passamos as regras em memória para não precisar ir ao banco a cada linha
            dados_limpos = cleaner.limpar_transacao(
                t['descricao_original'], 
                user_id=user_id, 
                token=token,
                regras_cacheadas=regras_usuario
            )
            
            if dados_limpos['categoria'] == "Outros":
                nome_final = t.get('nome_limpo', dados_limpos['name'])
                categoria_final = t.get('categoria_sugerida', "Outros")
            else:
                nome_final = dados_limpos['name']
                categoria_final = dados_limpos['categoria']
            
            icon_final = dados_limpos['icon'] 

            transacoes_prontas.append({
                "user_id": user_id,
                "data": t['data'] + "T12:00:00Z",
                "descricao": nome_final, 
                "valor": float(t['valor']),
                "categoria": categoria_final, 
                "icon": icon_final,
                "raw_data": t['descricao_original'] 
            })

        print(f"[CELERY] Inserindo {len(transacoes_prontas)} transacoes no Supabase...")
        supabase_db.insert_transactions_for_user(token, transacoes_prontas)

        cache_engine.invalidate_user_cache(user_id)
        
        print("[CELERY] Processamento concluido com sucesso!")
        return {"status": "success", "inserted": len(transacoes_prontas)}

    except Exception as e:
        print(f"[CELERY ERROR] Falha no processamento: {e}")
        return {"status": "error", "message": str(e)}
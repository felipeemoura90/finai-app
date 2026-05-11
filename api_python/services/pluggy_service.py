import os
import json
from datetime import datetime
from pluggy_sdk import ApiClient as PluggyClient
from config import settings
from services.ai_service import AIService
from services.supabase_service import SupabaseService

class PluggyService:
    def __init__(self):
        client_id = os.getenv("PLUGGY_CLIENT_ID")
        client_secret = os.getenv("PLUGGY_CLIENT_SECRET")
        
        if not client_id or not client_secret:
            print("[AVISO] Chaves da Pluggy não configuradas no .env")
            self.client = None
        else:
            self.client = PluggyClient()
        self.ai_service = AIService()
        self.supabase = SupabaseService()

    def get_connect_token(self) -> str:
        if self.client is None:
            raise Exception("PluggyClient not initialized - check .env keys")
        try:
            response = self.client.create_connect_token()
            return response.get("accessToken")
        except Exception as e:
            print(f"[ERRO] Falha ao gerar token da Pluggy: {e}")
            raise Exception("Não foi possível iniciar a conexão com o banco.")

    async def fetch_and_sync_transactions(self, item_id: str, user_id: str, access_token: str) -> dict:
        if self.client is None:
            raise Exception("PluggyClient not initialized - check .env keys")
        try:
            print(f"Iniciando sincronização para o item: {item_id}")
            accounts = self.client.fetch_accounts(item_id).get("results", [])
            
            processed_transactions = []

            for account in accounts:
                account_id = account.get("id")
                # Busca transações (a Pluggy traz dados detalhados)
                transactions = self.client.fetch_transactions(account_id).get("results", [])
                
                for tx in transactions:
                    # 1. Extração dos dados básicos
                    desc_original = tx.get("description", "Transação desconhecida")
                    valor = tx.get("amount", 0.0)
                    data_tx = tx.get("date") # Formato: YYYY-MM-DDTHH:MM:SSZ
                    pluggy_tx_id = tx.get("id")
                    
                    # 2. Categorização via IA (Gemini)
                    categoria = "Outros"
                    icone = "help-circle"
                    desc_limpa = desc_original
                    
                    try:
                        ai_result = await self.ai_service.categorize_transaction(desc_original, valor)
                        if ai_result:
                            categoria = ai_result.get("categoria", categoria)
                            icone = ai_result.get("icon", icone)
                            desc_limpa = ai_result.get("nome_limpo", desc_limpa)
                    except Exception as ai_e:
                        print(f"[AVISO] Falha ao categorizar '{desc_original}': {ai_e}")

                    # 3. Mapeamento para o formato do Supabase
                    processed_transactions.append({
                        "user_id": user_id,
                        "data": data_tx,
                        "descricao": desc_limpa,
                        "valor": valor,
                        "categoria": categoria,
                        "icon": icone,
                        "fitid": pluggy_tx_id, # Chave única para o Upsert
                        "raw_data": json.dumps(tx) # Guarda o dado original para auditoria
                    })

            # 4. Envio em lote para o Supabase
            if processed_transactions:
                self.supabase.insert_transactions_for_user(access_token, processed_transactions)
            
            return {
                "status": "success", 
                "total_contas": len(accounts),
                "total_transacoes_sincronizadas": len(processed_transactions)
            }
            
        except Exception as e:
            print(f"[ERRO] Falha ao sincronizar dados da Pluggy: {e}")
            raise Exception("Erro ao extrair e processar transações do banco.")
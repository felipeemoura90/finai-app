import os
import json
import requests
from services.ai_service import AIService
from services.supabase_service import SupabaseService

PLUGGY_BASE_URL = "https://api.pluggy.ai"

class PluggyService:
    def __init__(self):
        self.client_id = os.getenv("PLUGGY_CLIENT_ID")
        self.client_secret = os.getenv("PLUGGY_CLIENT_SECRET")
        
        if not self.client_id or not self.client_secret:
            print("[AVISO] Chaves da Pluggy não configuradas no .env")
        else:
            print("[OK] Pluggy configurada com credenciais.")

        self.ai_service = AIService()
        self.supabase = SupabaseService()

    def _get_api_key(self) -> str:
        """Etapa 1: Autentica com clientId/clientSecret e obtém um apiKey temporário."""
        response = requests.post(
            f"{PLUGGY_BASE_URL}/auth",
            json={"clientId": self.client_id, "clientSecret": self.client_secret},
            timeout=15,
        )
        if response.status_code != 200:
            raise Exception(f"Falha na autenticação Pluggy: {response.text}")
        api_key = response.json().get("apiKey")
        if not api_key:
            raise Exception("Pluggy não retornou apiKey.")
        return api_key

    def get_connect_token(self) -> str:
        """Etapa 2: Usa o apiKey para gerar um connectToken seguro para o widget."""
        if not self.client_id or not self.client_secret:
            raise Exception("Credenciais da Pluggy não configuradas no .env")
        try:
            api_key = self._get_api_key()
            response = requests.post(
                f"{PLUGGY_BASE_URL}/connect_token",
                headers={"x-api-key": api_key},
                json={},
                timeout=15,
            )
            if response.status_code != 200:
                raise Exception(f"Falha ao gerar connectToken: {response.text}")
            token = response.json().get("accessToken")
            if not token:
                raise Exception("Pluggy não retornou accessToken no connect_token.")
            print(f"[OK] Pluggy connectToken gerado com sucesso.")
            return token
        except Exception as e:
            print(f"[ERRO] Falha ao gerar token da Pluggy: {e}")
            raise Exception(f"Não foi possível iniciar a conexão com o banco: {e}")


    async def fetch_and_sync_transactions(self, item_id: str, user_id: str, access_token: str) -> dict:
        if not self.client_id or not self.client_secret:
            raise Exception("Credenciais da Pluggy não configuradas no .env")
        try:
            print(f"[Pluggy] Iniciando sincronização para o item: {item_id}")
            api_key = self._get_api_key()
            headers = {"x-api-key": api_key}

            # 1. Busca as contas do item
            accounts_resp = requests.get(
                f"{PLUGGY_BASE_URL}/accounts",
                headers=headers,
                params={"itemId": item_id},
                timeout=30,
            )
            accounts = accounts_resp.json().get("results", [])

            processed_transactions = []

            for account in accounts:
                account_id = account.get("id")
                # 2. Busca transações de cada conta
                tx_resp = requests.get(
                    f"{PLUGGY_BASE_URL}/transactions",
                    headers=headers,
                    params={"accountId": account_id, "pageSize": 500},
                    timeout=30,
                )
                transactions = tx_resp.json().get("results", [])

                for tx in transactions:
                    desc_original = tx.get("description", "Transação desconhecida")
                    valor = tx.get("amount", 0.0)
                    data_tx = tx.get("date")
                    pluggy_tx_id = tx.get("id")

                    # 3. Categorização via IA
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

                    processed_transactions.append({
                        "user_id": user_id,
                        "data": data_tx,
                        "descricao": desc_limpa,
                        "valor": valor,
                        "categoria": categoria,
                        "icon": icone,
                        "fitid": pluggy_tx_id,
                        "raw_data": json.dumps(tx)
                    })

            # 4. Salva no Supabase
            if processed_transactions:
                self.supabase.insert_transactions_for_user(access_token, processed_transactions)

            print(f"[OK] Sincronizadas {len(processed_transactions)} transações de {len(accounts)} contas.")
            return {
                "status": "success",
                "total_contas": len(accounts),
                "total_transacoes_sincronizadas": len(processed_transactions)
            }

        except Exception as e:
            print(f"[ERRO] Falha ao sincronizar dados da Pluggy: {e}")
            raise Exception(f"Erro ao extrair e processar transações do banco: {e}")
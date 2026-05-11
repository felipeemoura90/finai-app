import os
from pluggy import PluggyClient
from typing import List, Dict

class PluggyService:
    def __init__(self):
        # As chaves virão do seu .env configurado no passo anterior
        client_id = os.getenv("PLUGGY_CLIENT_ID")
        client_secret = os.getenv("PLUGGY_CLIENT_SECRET")
        
        if not client_id or not client_secret:
            print("[AVISO] Chaves da Pluggy não configuradas no .env")
            
        self.client = PluggyClient(
            client_id=client_id,
            client_secret=client_secret
        )

    def get_connect_token(self) -> str:
        """
        Gera um token temporário para o Flutter abrir o widget de conexão.
        """
        try:
            # O token expira rápido e é de uso único por sessão de conexão
            response = self.client.create_connect_token()
            return response.get("accessToken")
        except Exception as e:
            print(f"[ERRO] Falha ao gerar token da Pluggy: {e}")
            raise Exception("Não foi possível iniciar a conexão com o banco.")

    def fetch_and_sync_transactions(self, item_id: str, user_id: str) -> dict:
        """
        Busca as transações brutas de um item_id (banco recém conectado).
        """
        try:
            print(f"Iniciando sincronização para o item: {item_id}")
            
            # Passo 1: Pegar todas as contas bancárias atreladas a esta conexão
            accounts = self.client.fetch_accounts(item_id).get("results", [])
            all_raw_transactions = []

            # Passo 2: Para cada conta (Corrente, Poupança, Cartão de Crédito), puxar o extrato
            for account in accounts:
                account_id = account.get("id")
                
                # Puxamos as transações. O retorno trará os dados brutos reais, 
                # englobando desde compras de jogos na Steam até gastos com combustível ou peças para o Argo Trekking.
                transactions = self.client.fetch_transactions(account_id).get("results", [])
                all_raw_transactions.extend(transactions)

            # Aqui futuramente você chamará o ai_service.py para limpar os nomes 
            # e o supabase_service.py para salvar no banco.
            
            return {
                "status": "success", 
                "total_contas": len(accounts),
                "total_transacoes_encontradas": len(all_raw_transactions)
            }
            
        except Exception as e:
            print(f"[ERRO] Falha ao sincronizar dados da Pluggy: {e}")
            raise Exception("Erro ao extrair transações do banco.")
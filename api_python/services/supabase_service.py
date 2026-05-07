import os
import httpx
from supabase import create_client, Client
from config import settings
from typing import List, Dict

class SupabaseService:
    def __init__(self):
        url: str = settings.SUPABASE_URL
        key: str = settings.SUPABASE_ANON_KEY
        self.client: Client = create_client(url, key)
        self.url = url
        self.key = key

    def get_user_transactions(self, user_id: str, mes_ano: str, access_token: str) -> List[Dict]:
        """Busca transações usando a REST API para respeitar o RLS do Supabase"""
        try:
            start_date = f"{mes_ano}-01T00:00:00Z"
            ano, mes = map(int, mes_ano.split('-'))
            prox_mes = mes + 1 if mes < 12 else 1
            prox_ano = ano if mes < 12 else ano + 1
            end_date = f"{prox_ano}-{prox_mes:02d}-01T00:00:00Z"

            headers = {
                "apikey": self.key,
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
            }
            
            # Constrói a URL com os filtros equivalentes ao .eq(), .gte() e .lt()
            url = f"{self.url}/rest/v1/transactions?user_id=eq.{user_id}&data=gte.{start_date}&data=lt.{end_date}&select=*"
            
            with httpx.Client() as client:
                response = client.get(url, headers=headers, timeout=15.0)
                
            if response.status_code == 200:
                return response.json()
            else:
                print(f"[ERROR] Supabase retornou status {response.status_code}: {response.text}")
                return []
                
        except Exception as e:
            print(f"[ERROR] Erro ao buscar transacoes: {e}")
            return []

    def insert_transactions_for_user(self, access_token: str, transactions: List[Dict]):
        """Insere transações usando a REST API do Supabase com o JWT do usuário (fazendo UPSERT via FITID)"""
        if not transactions:
            return
            
        try:
            # 1. Adicionamos 'resolution=merge-duplicates' para forçar o Upsert
            headers = {
                "apikey": self.key,
                "Authorization": f"Bearer {access_token}",
                "Content-Type": "application/json",
                "Prefer": "resolution=merge-duplicates, return=representation",
            }
            
            # 2. Informamos a API que, em caso de conflito no 'fitid', ela deve atualizar em vez de duplicar
            url = f"{self.url}/rest/v1/transactions?on_conflict=fitid"
            
            with httpx.Client() as client:
                response = client.post(url, json=transactions, headers=headers, timeout=30.0)
                
            if response.status_code in (200, 201, 204):
                # Como a API pode retornar vazio num upsert, usamos .json() apenas se houver conteúdo
                data = response.json() if response.content else []
                print(f"[OK] Transações processadas no Supabase (Upsert).")
            else:
                print(f"[ERROR] Supabase retornou status {response.status_code}: {response.text}")
                
        except Exception as e:
            print(f"[ERROR] Erro ao inserir transacoes do usuario: {e}")


import os
import re
import httpx
from supabase import create_client, Client
from services.ai_service import AIService
from config import settings

class ClearingService:
    def __init__(self):
        url: str = settings.SUPABASE_URL
        key: str = settings.SUPABASE_ANON_KEY
        
        if not url or not key:
            print("[AVISO] Credenciais do Supabase ausentes.")
            
        self.supabase: Client = create_client(url, key)
        self.ai = AIService()
        
        # O dicionário global vazio serve apenas de fallback caso algum outro serviço antigo chame a classe
        self.dicionario = {} 

    def carregar_regras_usuario(self, user_id: str, token: str) -> dict:
        """Busca as regras exclusivas do usuário via REST API com o Token dele (Respeita RLS)"""
        dicionario = {}
        if not user_id or not token:
            return dicionario
            
        try:
            headers = {
                "apikey": settings.SUPABASE_ANON_KEY,
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json"
            }
            url = f"{settings.SUPABASE_URL}/rest/v1/regras?user_id=eq.{user_id}&select=*"
            
            with httpx.Client() as client:
                response = client.get(url, headers=headers, timeout=10.0)
                
            if response.status_code == 200:
                for row in response.json():
                    dicionario[row['keyword']] = {
                        "nome": row['name'], 
                        "categoria": row['categoria'], 
                        "icon": row['icon']
                    }
                print(f"[OK] {len(dicionario)} regras carregadas do banco para este usuário.")
            else:
                print(f"[ERRO REST] Falha ao carregar regras. Status: {response.status_code}")
                
        except Exception as e:
            print(f"[ERRO] Exceção ao carregar regras do usuário: {e}")
            
        return dicionario

    def salvar_regra(self, user_id: str, keyword: str, name: str, categoria: str, icon: str, token: str = None):
        """Adiciona ou Atualiza (UPSERT) uma regra no Supabase."""
        try:
            dados = {
                "user_id": user_id,
                "keyword": keyword.upper(),
                "name": name,
                "categoria": categoria,
                "icon": icon
            }
            
            if token:
                headers = {
                    "apikey": settings.SUPABASE_ANON_KEY,
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                    "Prefer": "resolution=merge-duplicates" 
                }
                
                # CORREÇÃO CRÍTICA DO ERRO 409: Informamos as colunas de conflito na URL
                url = f"{settings.SUPABASE_URL}/rest/v1/regras?on_conflict=user_id,keyword"
                
                with httpx.Client() as client:
                    response = client.post(url, json=dados, headers=headers, timeout=10.0)
                    
                if response.status_code in (200, 201, 204):
                    print(f"[OK] Regra '{keyword.upper()}' salva/atualizada no Supabase via REST.")
                else:
                    print(f"[ERRO REST] Falha ao salvar regra. Status {response.status_code}: {response.text}")
            else:
                self.supabase.table('regras').upsert(dados).execute()
                
        except Exception as e:
            print(f"[ERRO] Falha ao salvar regra no Supabase: {e}")

    def limpar_transacao(self, texto_bruto: str, user_id: str = None, token: str = None, regras_cacheadas: dict = None) -> dict:
        """Aplica a regra de limpeza consultando o dicionário local em memória."""
        texto_upper = str(texto_bruto).upper()
        
        # Usa o cache passado pela tarefa (ou um dicionário vazio se não enviaram nada)
        cache_local = regras_cacheadas if regras_cacheadas is not None else self.dicionario

        # 1. Verifica se a regra já existe no cache
        for chave, dados_limpos in cache_local.items():
            if chave in texto_upper:
                return {
                    "name": dados_limpos["nome"],
                    "categoria": dados_limpos["categoria"],
                    "icon": dados_limpos["icon"],
                    "trust": "high"
                }

        # 2. Se não encontrou, pede ajuda para a IA
        print(f"🤖 Usando IA para categorizar: {texto_bruto}")
        ai_result = self.ai.categorizar_transacao(texto_bruto)

        # 3. Salva a decisão e ATUALIZA O CACHE LOCAL instantaneamente
        if user_id:
            keyword = texto_upper[:20] 
            self.salvar_regra(
                user_id=user_id, 
                keyword=keyword, 
                name=ai_result["name"], 
                categoria=ai_result["categoria"], 
                icon=ai_result["icon"],
                token=token 
            )
            
            # Adiciona a regra recém-descoberta ao cache em memória da tarefa.
            # Se houver outra transação igual neste mesmo extrato, não chamará a IA novamente!
            if regras_cacheadas is not None:
                regras_cacheadas[keyword] = {
                    "nome": ai_result["name"],
                    "categoria": ai_result["categoria"],
                    "icon": ai_result["icon"]
                }

        return {
            "name": ai_result["name"],
            "categoria": ai_result["categoria"],
            "icon": ai_result["icon"],
            "trust": "ai" 
        }

    def _limpar_nome_desconhecido(self, texto: str) -> str:
        t = re.sub(r'\s+', ' ', texto).strip()
        return t[:25].title() + "..." if len(t) > 25 else t.title()
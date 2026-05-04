import os
import re
from supabase import create_client, Client
from services.ai_service import AIService
from config import settings

class ClearingService:
    def __init__(self):
        # Captura as credenciais que já existem no seu arquivo .env
        url: str = settings.SUPABASE_URL
        key: str = settings.SUPABASE_ANON_KEY
        
        if not url or not key:
            print("[AVISO] Credenciais do Supabase ausentes. O serviço de limpeza pode falhar.")
            
        # Inicializa a conexão direta com o banco de dados do Supabase
        self.supabase: Client = create_client(url, key)
        self.ai = AIService()
        
        # Carrega as regras logo ao iniciar o servidor
        self.dicionario = self._carregar_regras()

    def _carregar_regras(self):
        """Busca todas as regras no Supabase e coloca na memória RAM (Dicionário) para ser rápido."""
        dicionario = {}
        try:
            # Substitui o SELECT do SQLite pela chamada à API do Supabase
            response = self.supabase.table('regras').select('*').execute()
            
            for row in response.data:
                dicionario[row['keyword']] = {
                    "nome": row['name'], 
                    "categoria": row['categoria'], 
                    "icon": row['icon']
                }
            print(f"[OK] {len(dicionario)} regras carregadas do Supabase com sucesso.")
        except Exception as e:
            print(f"[ERRO] Falha ao carregar regras do Supabase: {e}")
            
        return dicionario

    def salvar_regra(self, keyword: str, name: str, categoria: str, icon: str):
        """Adiciona ou Atualiza (UPSERT) uma regra no Supabase e recarrega a memória."""
        try:
            dados = {
                "keyword": keyword.upper(),
                "name": name,
                "categoria": categoria,
                "icon": icon
            }
            # O comando 'upsert' faz o mesmo papel do 'ON CONFLICT DO UPDATE' do SQLite
            self.supabase.table('regras').upsert(dados).execute()
            
            print(f"[OK] Regra '{keyword.upper()}' salva/atualizada no Supabase.")
            
            # Atualiza a memória local para a regra já funcionar no próximo processamento
            self.dicionario = self._carregar_regras()
        except Exception as e:
            print(f"[ERRO] Falha ao salvar regra no Supabase: {e}")

    def limpar_transacao(self, texto_bruto: str) -> dict:
        """Aplica a regra de limpeza ou chama a IA se for desconhecido (Mantido intacto)"""
        texto_upper = str(texto_bruto).upper()

        # 1. Tenta achar no dicionário carregado do banco
        for chave, dados_limpos in self.dicionario.items():
            if chave in texto_upper:
                return {
                    "name": dados_limpos["nome"],
                    "categoria": dados_limpos["categoria"],
                    "icon": dados_limpos["icon"],
                    "trust": "high"
                }

        # 2. Se não encontrou, pede ajuda para a IA do Gemini
        print(f"🤖 Usando IA para categorizar: {texto_bruto}")
        ai_result = self.ai.categorizar_transacao(texto_bruto)

        # 3. Salva a decisão da IA automaticamente no Supabase
        keyword = texto_upper[:20] 
        self.salvar_regra(keyword, ai_result["name"], ai_result["categoria"], ai_result["icon"])

        return {
            "name": ai_result["name"],
            "categoria": ai_result["categoria"],
            "icon": ai_result["icon"],
            "trust": "ai" 
        }

    def _limpar_nome_desconhecido(self, texto: str) -> str:
        t = re.sub(r'\s+', ' ', texto).strip()
        return t[:25].title() + "..." if len(t) > 25 else t.title()
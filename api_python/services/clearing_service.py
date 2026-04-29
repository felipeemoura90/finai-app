# IMPORTAÇÃO DO NOVO SERVIÇO DE IA
import os
import sqlite3
import re
from services.ai_service import AIService

class ClearingService:
    def __init__(self):
        self.db_path = "data/regras.db"
        self._inicializar_banco()
        self.dicionario = self._carregar_regras()
        self.ai = AIService()  # Inicializar serviço de IA

    def _inicializar_banco(self):
        os.makedirs("data", exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Cria a tabela de regras se não existir
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS regras (
                keyword TEXT PRIMARY KEY,
                name TEXT,
                categoria TEXT,
                icon TEXT
            )
        ''')
        
        # Verifica se o banco está vazio. Se sim, popula com as regras iniciais.
        cursor.execute("SELECT COUNT(*) FROM regras")
        if cursor.fetchone()[0] == 0:
            regras_iniciais = [
                ("CONDOR", "Supermercado Condor", "Mercado", "shopping_cart"),
                ("ANGELONI", "Angeloni", "Mercado", "shopping_cart"),
                ("KOCH", "Komprão Koch", "Mercado", "shopping_cart"),
                ("GIASSI", "Giassi Supermercados", "Mercado", "shopping_cart"),
                ("FUTEBOL E LANCHONETE", "Lanchonete (Futebol)", "Alimentação", "restaurant"),
                ("CELESC", "Energia Elétrica (Celesc)", "Contas Fixas", "bolt"),
                ("CLARO", "Internet/Celular (Claro)", "Contas Fixas", "wifi"),
                ("SOCIESC", "Faculdade (UniSociesc)", "Educação", "school"),
                ("HAPVIDA", "Plano de Saúde (Hapvida)", "Saúde", "medical_services"),
                ("FARMACIA", "Farmácia", "Saúde", "local_pharmacy"),
                ("POSTO", "Posto de Combustível", "Transporte", "local_gas_station")
            ]
            cursor.executemany("INSERT INTO regras VALUES (?, ?, ?, ?)", regras_iniciais)
            conn.commit()
            
        conn.close()

    def _carregar_regras(self):
        """Lê todas as regras do SQLite e coloca na memória para ser rápido."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT keyword, name, categoria, icon FROM regras")
        
        dicionario = {}
        for row in cursor.fetchall():
            dicionario[row[0]] = {"nome": row[1], "categoria": row[2], "icon": row[3]}
            
        conn.close()
        return dicionario

    def salvar_regra(self, keyword: str, name: str, categoria: str, icon: str):
        """Adiciona ou Atualiza uma regra no banco e recarrega a memória."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # UPSERT: Se a palavra-chave já existir, ele atualiza os dados!
        cursor.execute('''
            INSERT INTO regras (keyword, name, categoria, icon) 
            VALUES (?, ?, ?, ?)
            ON CONFLICT(keyword) DO UPDATE SET
                name=excluded.name,
                categoria=excluded.categoria,
                icon=excluded.icon
        ''', (keyword.upper(), name, categoria, icon))
        
        conn.commit()
        conn.close()
        
        # Atualiza a memória instantaneamente
        self.dicionario = self._carregar_regras()

    def limpar_transacao(self, texto_bruto: str) -> dict:
        texto_upper = str(texto_bruto).upper()

        for chave, dados_limpos in self.dicionario.items():
            if chave in texto_upper:
                return {
                    "name": dados_limpos["nome"],
                    "categoria": dados_limpos["categoria"],
                    "icon": dados_limpos["icon"],
                    "trust": "high"
                }

        # Se não encontrou no banco, usar IA para categorizar
        print(f"🤖 Usando IA para categorizar: {texto_bruto}")
        ai_result = self.ai.categorizar_transacao(texto_bruto)

        # Salvar automaticamente a nova regra no banco
        keyword = texto_upper[:20]  # Usar os primeiros 20 chars como chave
        self.salvar_regra(keyword, ai_result["name"], ai_result["categoria"], ai_result["icon"])

        return {
            "name": ai_result["name"],
            "categoria": ai_result["categoria"],
            "icon": ai_result["icon"],
            "trust": "ai"  # Nova confiança: categorizada por IA
        }

    def _limpar_nome_desconhecido(self, texto: str) -> str:
        t = re.sub(r'\s+', ' ', texto).strip()
        return t[:25].title() + "..." if len(t) > 25 else t.title()
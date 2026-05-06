import pandas as pd
from ofxparse import OfxParser
import io
import re
import os
import calendar
from services.clearing_service import ClearingService 

class OfxService:
    def __init__(self, filepath="data/extrato.ofx"):
        self.cleaner = ClearingService()
        self.atualizar_arquivo(filepath)

    def atualizar_arquivo(self, filepath: str):
        self.filepath = filepath
        
        if not os.path.exists(filepath):
            self.df = pd.DataFrame()
            return

        extensao = filepath.split('.')[-1].lower()

        try:
            if extensao == 'ofx':
                self.df = self._load_and_process_ofx(filepath)
            elif extensao == 'csv':
                self.df = self._load_and_process_csv(filepath)
            elif extensao in ['xls', 'xlsx']:
                self.df = self._load_and_process_excel(filepath)
            else:
                self.df = pd.DataFrame()
        except Exception as e:
            print(f"[ERRO] Falha crítica ao ler o arquivo: {e}")
            self.df = pd.DataFrame()

    def injetar_transacoes(self, transacoes: list):
        if not transacoes:
            self.df = pd.DataFrame()
            return
            
        self.df = pd.DataFrame(transacoes)
        self.df['data'] = pd.to_datetime(self.df['data'], utc=True).dt.tz_localize(None)
        self.df['mes_ano'] = self.df['data'].dt.strftime('%Y-%m')
        
        self.df['id'] = self.df['id'].astype(str) if 'id' in self.df.columns else self.df.index.astype(str)
        print(f"[OK] Injetadas {len(self.df)} transações do Supabase no motor Pandas.")

    def _padronizar_dataframe(self, df):
        df.columns = df.columns.astype(str).str.lower().str.strip()
        
        col_data = next((c for c in df.columns if 'data' in c), None)
        col_desc = next((c for c in df.columns if 'histórico' in c or 'descrição' in c or 'detalhe' in c or 'title' in c), None)
        col_valor = next((c for c in df.columns if 'valor' in c or 'saída' in c or 'entrada' in c or 'amount' in c), None)
        
        if not (col_data and col_desc and col_valor):
            return pd.DataFrame()
            
        df = df.rename(columns={col_data: 'data', col_desc: 'descricao', col_valor: 'valor'})
        
        if df['valor'].dtype == 'O': 
            df['valor'] = df['valor'].astype(str).str.replace('R$', '', regex=False).str.replace('.', '', regex=False).str.replace(',', '.', regex=False).astype(float)
            
        df['data'] = pd.to_datetime(df['data'], format='mixed', dayfirst=True)
        df['mes_ano'] = df['data'].dt.strftime('%Y-%m')
        df['id'] = df.index.astype(str)
        
        return df

    def _load_and_process_csv(self, filepath):
        try:
            df = pd.read_csv(filepath, sep=';', encoding='latin-1')
        except:
            df = pd.read_csv(filepath, sep=',', encoding='utf-8')
        return self._padronizar_dataframe(df)

    def _load_and_process_excel(self, filepath):
        df = pd.read_excel(filepath)
        return self._padronizar_dataframe(df)

    def _load_and_process_ofx(self, filepath):
        if not os.path.exists(self.filepath):
            return pd.DataFrame() 
        with open(self.filepath, 'r', encoding='latin-1') as fileobj:
            ofx_content = fileobj.read()
        ofx_content = ofx_content.replace('UTF - 8', 'UTF-8')
        ofx_content = re.sub(r'\[[-+]?\d+:BRT\]', '', ofx_content)
        ofx_io = io.BytesIO(ofx_content.encode('utf-8'))
        try:
            ofx = OfxParser.parse(ofx_io)
        except Exception as e:
            return pd.DataFrame()
        transacoes = []
        for account in ofx.accounts:
            for tx in account.statement.transactions:
                transacoes.append({"data": tx.date,"descricao": tx.memo,"valor": float(tx.amount),"id": tx.id})
        if not transacoes: return pd.DataFrame()
        df = pd.DataFrame(transacoes)
        df['data'] = pd.to_datetime(df['data'], utc=True).dt.tz_localize(None)
        df['mes_ano'] = df['data'].dt.strftime('%Y-%m')
        return df

    def obter_resumo_mes(self, mes_ano: str):
        if self.df.empty: return 0.0
        df_mes = self.df[self.df['mes_ano'] == mes_ano]
        return float(df_mes['valor'].sum())
    
    def obter_resumo_dashboard(self, mes_ano: str, meta_mensal: float = 3000.0):
        if self.df.empty:
            return {"ganhos": 0.0, "gastos": 0.0, "saldo": 0.0, "insight_ia": "Sem dados disponíveis", "categorias": []}
            
        df_mes = self.df[self.df['mes_ano'] == mes_ano]
        if df_mes.empty:
            return {"ganhos": 0.0, "gastos": 0.0, "saldo": 0.0, "insight_ia": "Sem dados para este mês", "categorias": []}

        ganhos = float(df_mes[df_mes['valor'] > 0]['valor'].sum())
        gastos = float(abs(df_mes[df_mes['valor'] < 0]['valor'].sum()))
        saldo = ganhos - gastos

        categorias_soma = {}
        df_gastos_mes = df_mes[df_mes['valor'] < 0].copy()
        df_gastos_mes['valor'] = df_gastos_mes['valor'].abs()
        
        for index, row in df_gastos_mes.iterrows():
            # Lê a categoria diretamente do banco de dados injetado
            cat = row.get('categoria', 'Outros')
            val = float(row['valor'])
            categorias_soma[cat] = categorias_soma.get(cat, 0.0) + val

        lista_categorias = [{"nome": k, "valor": v} for k, v in categorias_soma.items()]
        lista_categorias = sorted(lista_categorias, key=lambda x: x['valor'], reverse=True)

        # O insight da IA se mantém, pois é apenas um parágrafo consultado uma única vez
        dados_para_ia = {
            "ganhos": ganhos,
            "gastos": gastos,
            "saldo": saldo,
            "meta": meta_mensal,
            "categorias": lista_categorias
        }
        insight_ia = self.cleaner.ai.gerar_insight_personalizado(dados_para_ia)

        return {
            "ganhos": ganhos,
            "gastos": gastos,
            "saldo": saldo,
            "insight_ia": insight_ia,
            "categorias": lista_categorias
        }
    
    def obter_extrato_feed(self, mes_ano: str):
        if self.df.empty: 
            return []

        df_mes = self.df[self.df['mes_ano'] == mes_ano]
        if df_mes.empty: 
            return []

        df_gastos_mes = df_mes[df_mes['valor'] < 0].copy()
        df_gastos_mes['valor'] = df_gastos_mes['valor'].abs()

        resultado = []
        for index, row in df_gastos_mes.iterrows():
            # Lê os dados limpos diretamente do banco sem chamar IA
            resultado.append({
                "raw": str(row.get('raw_data', row.get('descricao', ''))),
                "name": str(row.get('descricao', 'Transação')), 
                "categoria": str(row.get('categoria', 'Outros')),
                "icon": str(row.get('icon', 'help_outline')),
                "trust": "high", 
                "value": f"R$ {abs(float(row['valor'])):.2f}"
            })
            
        return resultado

    def obter_transacoes_mes(self, mes_ano: str):
        if self.df.empty: return []
        df_mes = self.df[self.df['mes_ano'] == mes_ano]
        
        resultado = []
        for index, row in df_mes.iterrows():
            resultado.append({
                "id": str(row.get('id', '')),
                "raw": str(row.get('raw_data', row.get('descricao', ''))),
                "value": f"R$ {row['valor']:.2f}".replace('.', ','),
                "name": str(row.get('descricao', 'Transação')),
                "icon": str(row.get('icon', 'help_outline')),
                "trust": "high",
                "categoria": str(row.get('categoria', 'Outros'))
            })
        return resultado

    def obter_fluxo_diario(self, mes_ano: str):
        if self.df.empty: return []
        
        ano, mes = map(int, mes_ano.split('-'))
        
        data_inicio_mes = pd.Timestamp(year=ano, month=mes, day=1)
        df_anterior = self.df[self.df['data'] < data_inicio_mes]
        saldo_inicial = float(df_anterior['valor'].sum()) if not df_anterior.empty else 0.0
        
        df_mes = self.df[self.df['mes_ano'] == mes_ano]
        
        agrupado_liquido = {}
        transacoes_por_dia = {} 
        
        if not df_mes.empty:
            agrupado_liquido = df_mes.groupby(df_mes['data'].dt.day)['valor'].sum().to_dict()
            
            for index, row in df_mes.iterrows():
                dia = row['data'].day
                if dia not in transacoes_por_dia:
                    transacoes_por_dia[dia] = []
                
                # Lê os dados limpos diretamente do banco
                transacoes_por_dia[dia].append({
                    "descricao": str(row.get('descricao', 'Transação')),
                    "valor": float(row['valor'])
                })
         
        ultimo_dia = calendar.monthrange(ano, mes)[1]
        resultado = []
        saldo_atual = saldo_inicial
        
        for dia in range(1, ultimo_dia + 1):
            movimento_dia = float(agrupado_liquido.get(dia, 0.0))
            saldo_atual += movimento_dia
            
            resultado.append({
                "dia": dia,
                "valor": saldo_atual, 
                "movimento": movimento_dia,
                "transacoes": transacoes_por_dia.get(dia, []) 
            })
            
        return resultado
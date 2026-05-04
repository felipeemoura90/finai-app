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
        # O construtor agora chama a função dinâmica
        self.atualizar_arquivo(filepath)

    def atualizar_arquivo(self, filepath: str):
        """Descobre a extensão do arquivo e usa o leitor correto"""
        self.filepath = filepath
        
        if not os.path.exists(filepath):
            print(f"[AVISO] Arquivo base {filepath} não encontrado.")
            self.df = pd.DataFrame()
            return

        extensao = filepath.split('.')[-1].lower()
        print(f"[INFO] Processando arquivo formato: {extensao.upper()}")

        try:
            if extensao == 'ofx':
                self.df = self._load_and_process_ofx(filepath)
            elif extensao == 'csv':
                self.df = self._load_and_process_csv(filepath)
            elif extensao in ['xls', 'xlsx']:
                self.df = self._load_and_process_excel(filepath)
            else:
                print(f"[ERRO] Formato não suportado: {extensao}")
                self.df = pd.DataFrame()
        except Exception as e:
            print(f"[ERRO] Falha crítica ao ler o arquivo: {e}")
            self.df = pd.DataFrame()

    def injetar_transacoes(self, transacoes: list):
        """Injeta transações vindas do banco de dados (Supabase) diretamente no DataFrame do Pandas"""
        if not transacoes:
            self.df = pd.DataFrame()
            return
            
        self.df = pd.DataFrame(transacoes)
        
        # --- CORREÇÃO AQUI ---
        # Garante que a coluna data seja datetime E remove o timezone (fuso) para não crashar o Fluxo!
        self.df['data'] = pd.to_datetime(self.df['data'], utc=True).dt.tz_localize(None)
        # ---------------------
        
        self.df['mes_ano'] = self.df['data'].dt.strftime('%Y-%m')
        
        # Pega a descrição limpa e o valor
        self.df['id'] = self.df['id'].astype(str) if 'id' in self.df.columns else self.df.index.astype(str)
        print(f"[OK] Injetadas {len(self.df)} transações do Supabase no motor Pandas.")

    def _padronizar_dataframe(self, df):
        """Uma peneira inteligente para achar as colunas em qualquer Excel/CSV de banco"""
        df.columns = df.columns.astype(str).str.lower().str.strip()
        
        # Caçador de colunas
        col_data = next((c for c in df.columns if 'data' in c), None)
        col_desc = next((c for c in df.columns if 'histórico' in c or 'descrição' in c or 'detalhe' in c or 'title' in c), None)
        col_valor = next((c for c in df.columns if 'valor' in c or 'saída' in c or 'entrada' in c or 'amount' in c), None)
        
        if not (col_data and col_desc and col_valor):
            print("[ERRO] Não foi possível encontrar as colunas Data, Descrição e Valor na planilha.")
            return pd.DataFrame()
            
        # Renomeia para o padrão que as suas rotas já esperam
        df = df.rename(columns={col_data: 'data', col_desc: 'descricao', col_valor: 'valor'})
        
        # Limpeza pesada caso o valor venha como texto tipo "R$ -50,00"
        if df['valor'].dtype == 'O': 
            df['valor'] = df['valor'].astype(str).str.replace('R$', '', regex=False).str.replace('.', '', regex=False).str.replace(',', '.', regex=False).astype(float)
            
        df['data'] = pd.to_datetime(df['data'], format='mixed', dayfirst=True)
        df['mes_ano'] = df['data'].dt.strftime('%Y-%m')
        df['id'] = df.index.astype(str) # Cria um ID genérico
        
        print(f"[OK] Planilha lida com sucesso! {len(df)} transações.")
        return df

    def _load_and_process_csv(self, filepath):
        try:
            # Tenta o padrão do Brasil (separado por ponto e vírgula)
            df = pd.read_csv(filepath, sep=';', encoding='latin-1')
        except:
            # Fallback pro padrão americano (separado por vírgula)
            df = pd.read_csv(filepath, sep=',', encoding='utf-8')
        return self._padronizar_dataframe(df)

    def _load_and_process_excel(self, filepath):
        df = pd.read_excel(filepath)
        return self._padronizar_dataframe(df)

    def _load_and_process_ofx(self, filepath):
        # ... (Todo esse método continua EXATAMENTE igual, não precisa mudar nada aqui)
        # (Lê o arquivo, filtra os gatos, etc)
        # ...
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
        # Mantém todas as transações: receitas (positivas) e gastos (negativas)
        print(f"[OK] OFX LIDO COM SUCESSO! {len(df)} transacoes.")
        return df

    def obter_resumo_mes(self, mes_ano: str):
        if self.df.empty: return 0.0
        df_mes = self.df[self.df['mes_ano'] == mes_ano]
        return float(df_mes['valor'].sum())
    
    def obter_resumo_dashboard(self, mes_ano: str, meta_mensal: float = 3000.0):
        """Calcula ganhos, gastos, saldo e agrupa os valores por categoria."""
        if self.df.empty:
            return {"ganhos": 0.0, "gastos": 0.0, "saldo": 0.0, "insight_ia": "Sem dados disponíveis", "categorias": []}
            
        df_mes = self.df[self.df['mes_ano'] == mes_ano]
        if df_mes.empty:
            return {"ganhos": 0.0, "gastos": 0.0, "saldo": 0.0, "insight_ia": "Sem dados para este mês", "categorias": []}

        # Calcula ganhos (valores positivos) e gastos (valores negativos absolutos)
        ganhos = float(df_mes[df_mes['valor'] > 0]['valor'].sum())
        gastos = float(abs(df_mes[df_mes['valor'] < 0]['valor'].sum()))
        saldo = ganhos - gastos

        # Agrupa os gastos usando o nosso dicionário de limpeza (apenas para gastos)
        categorias_soma = {}
        df_gastos_mes = df_mes[df_mes['valor'] < 0].copy()
        df_gastos_mes['valor'] = df_gastos_mes['valor'].abs()
        for index, row in df_gastos_mes.iterrows():
            dados_limpos = self.cleaner.limpar_transacao(row['descricao'])
            cat = dados_limpos["categoria"]
            val = float(row['valor'])
            # Soma o valor na categoria correspondente
            categorias_soma[cat] = categorias_soma.get(cat, 0.0) + val

        # Converte para uma lista e ordena da categoria com maior gasto para a menor
        lista_categorias = [{"nome": k, "valor": v} for k, v in categorias_soma.items()]
        lista_categorias = sorted(lista_categorias, key=lambda x: x['valor'], reverse=True)

        # Gerar insight personalizado com IA
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
        """Retorna a lista detalhada de transações de gastos para o Feed."""
        # Se não tem dados, devolve lista vazia (nunca None/null!)
        if self.df.empty: 
            return []

        df_mes = self.df[self.df['mes_ano'] == mes_ano]
        if df_mes.empty: 
            return []

        # Filtra apenas gastos (valores negativos) para o feed
        df_gastos_mes = df_mes[df_mes['valor'] < 0].copy()
        df_gastos_mes['valor'] = df_gastos_mes['valor'].abs()

        resultado = []
        for index, row in df_gastos_mes.iterrows():
            # Tenta pegar o texto feio original. Se não existir, pega a descrição normal.
            texto_bruto = str(row.get('raw_data', row['descricao']))
            dados_limpos = self.cleaner.limpar_transacao(texto_bruto)
            
            # Monta o pacote EXATAMENTE como o Flutter espera
            resultado.append({
                "raw": texto_bruto,
                "name": dados_limpos["name"],
                "categoria": dados_limpos["categoria"],
                "icon": dados_limpos["icon"],
                "trust": dados_limpos["trust"],
                "value": f"R$ {abs(float(row['valor'])):.2f}" # Valor bonitinho, ex: R$ 50.00
            })
            
        return resultado

    # --- ATUALIZANDO O MÉTODO QUE ENVIA OS DADOS PARA O FEED ---
    def obter_transacoes_mes(self, mes_ano: str):
        if self.df.empty: return []
        df_mes = self.df[self.df['mes_ano'] == mes_ano]
        
        resultado = []
        for index, row in df_mes.iterrows():
            descricao_bruta = row['descricao']
            
            # PASSA O TEXTO FEIO PELO CÉREBRO DE LIMPEZA
            dados_limpos = self.cleaner.limpar_transacao(descricao_bruta)
            
            resultado.append({
                "id": row['id'],
                "raw": descricao_bruta,
                "value": f"R$ {row['valor']:.2f}".replace('.', ','),
                
                # Usa os dados limpos que vieram do dicionário
                "name": dados_limpos["name"],
                "icon": dados_limpos["icon"],
                "trust": dados_limpos["trust"],
                "categoria": dados_limpos["categoria"]
            })
    def obter_fluxo_diario(self, mes_ano: str):
        """Calcula o saldo cumulativo dia a dia, trazendo o histórico de meses anteriores."""
        if self.df.empty: return []
        
        ano, mes = map(int, mes_ano.split('-'))
        
        # 1. Puxa o saldo do passado
        data_inicio_mes = pd.Timestamp(year=ano, month=mes, day=1)
        df_anterior = self.df[self.df['data'] < data_inicio_mes]
        saldo_inicial = float(df_anterior['valor'].sum()) if not df_anterior.empty else 0.0
        
        df_mes = self.df[self.df['mes_ano'] == mes_ano]
        
        agrupado_liquido = {}
        transacoes_por_dia = {} # NOVO: Dicionário para guardar as transações
        
        if not df_mes.empty:
            agrupado_liquido = df_mes.groupby(df_mes['data'].dt.day)['valor'].sum().to_dict()
            
            # NOVO: Montar a lista de transações dia a dia usando o Cérebro de Limpeza
            for index, row in df_mes.iterrows():
                dia = row['data'].day
                if dia not in transacoes_por_dia:
                    transacoes_por_dia[dia] = []
                
                dados_limpos = self.cleaner.limpar_transacao(row['descricao'])
                transacoes_por_dia[dia].append({
                    "descricao": dados_limpos["name"], # Alterado de "name" para "descricao"
                    "valor": float(row['valor'])       # Alterado de "value" para "valor"
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
                "transacoes": transacoes_por_dia.get(dia, []) # NOVO: Envia a lista!
            })
            
        return resultado
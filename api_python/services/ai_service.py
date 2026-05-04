import os
import json
import google.generativeai as genai
from typing import Dict, List, Optional
from config import settings

class AIService:
    def __init__(self, api_key: Optional[str] = None):
        # Configurar a chave da API
        self.api_key = api_key or settings.GEMINI_API_KEY
        print(f"[INFO] Chave API final: {self.api_key[:20]}..." if self.api_key else "[ERROR] Nenhuma chave encontrada")
        if not self.api_key:
            print("[WARNING] GEMINI_API_KEY nao encontrada. IA desabilitada.")
            self.enabled = False
            return

        print(f"[INFO] Chave API carregada: {self.api_key[:20]}...")
        genai.configure(api_key=self.api_key)
        self.model = genai.GenerativeModel('gemini-2.0-flash')
        self.enabled = True
        print("[OK] IA Gemini conectada com sucesso!")

    def categorizar_transacao(self, texto_bruto: str) -> Dict[str, str]:
        """
        Usa IA para categorizar uma transação desconhecida.
        Retorna: {"name": str, "categoria": str, "icon": str}
        """
        fallback = {
            "name": texto_bruto[:25].title(),
            "categoria": "Outros",
            "icon": "help_outline"
        }

        prompt = f"""Analise esta transacao bancaria e categorize-a.

Transacao: "{texto_bruto}"

Retorne APENAS um JSON valido no formato:
{{
    "name": "Nome limpo da transacao (max 25 chars)",
    "categoria": "Uma das categorias: Mercado, Alimentacao, Contas Fixas, Saude, Transporte, Educacao, Transferencia, Servicos, Outros",
    "icon": "Icone do Material Design: shopping_cart, restaurant, bolt, wifi, local_pharmacy, local_gas_station, school, compare_arrows, help_outline, payment, local_cafe"
}}"""

        # Tenta Groq primeiro
        groq_key = settings.GROQ_API_KEY
        if groq_key:
            try:
                from groq import Groq
                client = Groq(api_key=groq_key)
                response = client.chat.completions.create(
                    model="llama-3.3-70b-versatile",
                    messages=[
                        {"role": "system", "content": "Voce categoriza transacoes financeiras. Responda APENAS com JSON valido."},
                        {"role": "user", "content": prompt},
                    ],
                    temperature=0.1,
                    max_tokens=150,
                )
                result = json.loads(response.choices[0].message.content.strip())
                result["name"] = result.get("name", texto_bruto[:25].title())[:25]
                result["categoria"] = result.get("categoria", "Outros")
                result["icon"] = result.get("icon", "help_outline")
                return result
            except Exception as e:
                print(f"[WARNING] Groq categorizacao falhou: {e}")

        # Fallback: Gemini
        if self.enabled:
            try:
                response = self.model.generate_content(prompt)
                texto_resp = response.text.strip()
                if texto_resp.startswith("```"):
                    texto_resp = texto_resp.split("```")[1]
                    if texto_resp.startswith("json"):
                        texto_resp = texto_resp[4:]
                result = json.loads(texto_resp.strip())
                result["name"] = result.get("name", texto_bruto[:25].title())[:25]
                result["categoria"] = result.get("categoria", "Outros")
                result["icon"] = result.get("icon", "help_outline")
                return result
            except Exception as e:
                print(f"[WARNING] Gemini categorizacao falhou: {e}")

        return fallback

    def gerar_insight_personalizado(self, dados_mes: Dict) -> str:
        """
        Gera um insight personalizado baseado nos dados do mês.
        """
        if not self.enabled:
            print("[WARNING] IA desabilitada")
            return "IA desabilitada - insight automático."

        ganhos = dados_mes.get("ganhos", 0)
        gastos = dados_mes.get("gastos", 0)
        saldo = dados_mes.get("saldo", 0)
        meta = dados_mes.get("meta", 3000)
        categorias = dados_mes.get("categorias", [])

        print(f"[INFO] Dados para IA: ganhos={ganhos:.2f}, gastos={gastos:.2f}, saldo={saldo:.2f}, meta={meta:.2f}")

        # Preparar dados das categorias para o prompt
        categorias_texto = "\n".join([
            f"- {cat['nome']}: R$ {cat['valor']:.2f}"
            for cat in categorias[:5]  # Top 5 categorias
        ])

        prompt = f"""Analise estes dados financeiros do mes e gere um insight personalizado e util.

Dados do mes:
- Ganhos: R$ {ganhos:.2f}
- Gastos: R$ {gastos:.2f}
- Saldo: R$ {saldo:.2f}
- Meta mensal: R$ {meta:.2f}

Principais categorias de gasto:
{categorias_texto}

Escreva um paragrafo curto (max 100 palavras) com:
1. Uma observacao positiva sobre os ganhos/gastos
2. Uma dica especifica baseada nos dados
3. Uma sugestao pratica para o proximo mes

Seja amigavel e direto ao ponto."""

        insight_padrao = f"Seu saldo do mes foi de R$ {saldo:.2f}. Mantenha o controle dos gastos!"

        # Tenta Groq primeiro (rapido e gratuito)
        groq_key = settings.GROQ_API_KEY
        if groq_key:
            try:
                from groq import Groq
                client = Groq(api_key=groq_key)
                response = client.chat.completions.create(
                    model="llama-3.3-70b-versatile",
                    messages=[
                        {"role": "system", "content": "Voce e um consultor financeiro amigavel. Responda em portugues."},
                        {"role": "user", "content": prompt},
                    ],
                    temperature=0.7,
                    max_tokens=300,
                )
                insight = response.choices[0].message.content.strip()
                if len(insight) > 200:
                    insight = insight[:200] + "..."
                print(f"[OK] Insight gerado pelo Groq: {insight[:50]}...")
                return insight
            except Exception as e:
                print(f"[WARNING] Groq insight falhou: {e}")

        # Fallback: Gemini
        if self.enabled:
            try:
                response = self.model.generate_content(prompt)
                insight = response.text.strip()
                if len(insight) > 200:
                    insight = insight[:200] + "..."
                return insight
            except Exception as e:
                print(f"[WARNING] Gemini insight falhou: {e}")

        return insight_padrao

    def _get_prompt_extracao(self, texto_cortado: str) -> str:
        """Gera o prompt padronizado para extração de transações"""
        return f"""Voce e um assistente financeiro especialista em leitura de extratos bancarios.
Abaixo, voce recebera o conteudo bruto de um arquivo de extrato bancario (pode ser CSV, TXT ou OFX).
Sua tarefa e extrair todas as transacoes financeiras desse texto e converte-las em um formato JSON estrito.

Regras de extracao:
- O valor deve ser um numero float. Despesas/saidas devem ser NEGATIVAS. Entradas/receitas devem ser POSITIVAS.
- A data deve estar no formato "YYYY-MM-DD".
- A descricao deve ser o mais limpa possivel.
- Ignore linhas de cabecalho, saldos anteriores e lixo.

Texto bruto do arquivo:
'''
{texto_cortado}
'''

Retorne APENAS um array JSON valido, sem markdown, contendo objetos com este formato exato:
[
    {{
        "data": "2023-10-25",
        "descricao": "NOME DO GASTO OU RECEITA",
        "valor": -150.50
    }},
    ...
]"""

    def _limpar_resposta_json(self, texto_resposta: str) -> list:
        """Remove blocos de markdown e parseia o JSON da resposta da IA"""
        texto_resposta = texto_resposta.strip()
        if texto_resposta.startswith("```json"):
            texto_resposta = texto_resposta[7:]
        if texto_resposta.startswith("```"):
            texto_resposta = texto_resposta[3:]
        if texto_resposta.endswith("```"):
            texto_resposta = texto_resposta[:-3]
        return json.loads(texto_resposta.strip())

    def extrair_transacoes_do_arquivo(self, texto_bruto: str) -> List[Dict]:
        """
        Extrai transacoes de um arquivo usando Groq (Llama) como motor principal
        e Gemini como fallback.
        """
        import re
        # Remove tags XML/OFX que sao lixo para a IA (ex: <STMTTRN>, </TRNAMT>, etc.)
        texto_limpo = re.sub(r'<[^>]+>', ' ', texto_bruto)
        # Remove linhas vazias e espaços extras
        texto_limpo = re.sub(r'\s+', ' ', texto_limpo).strip()
        
        # Limita o texto para caber no limite de tokens
        texto_cortado = texto_limpo[:8000]
        prompt = self._get_prompt_extracao(texto_cortado)

        # ====== TENTATIVA 1: GROQ (gratuito) ======
        groq_key = settings.GROQ_API_KEY
        if groq_key:
            try:
                from groq import Groq
                print(f"[INFO] Usando Groq para ler o extrato ({len(texto_cortado)} chars)...")
                client = Groq(api_key=groq_key)
                
                response = client.chat.completions.create(
                    model="llama-3.3-70b-versatile",
                    messages=[
                        {"role": "system", "content": "Voce e um assistente financeiro que extrai transacoes de extratos bancarios. Responda APENAS com JSON valido, sem texto extra."},
                        {"role": "user", "content": prompt},
                    ],
                    temperature=0.1,
                    max_tokens=4000,
                )
                
                texto_resposta = response.choices[0].message.content
                transacoes = self._limpar_resposta_json(texto_resposta)
                print(f"[OK] Groq extraiu {len(transacoes)} transacoes com sucesso!")
                return transacoes
                
            except Exception as e:
                print(f"[WARNING] Groq falhou: {e}. Tentando Gemini...")

        # ====== TENTATIVA 2: GEMINI (fallback) ======
        if self.enabled:
            try:
                print("[INFO] Usando Gemini como fallback para ler o extrato...")
                response = self.model.generate_content(prompt)
                transacoes = self._limpar_resposta_json(response.text)
                print(f"[OK] Gemini extraiu {len(transacoes)} transacoes com sucesso!")
                return transacoes
            except Exception as e:
                print(f"[ERROR] Gemini tambem falhou: {e}")

        print("[ERROR] Nenhuma IA disponivel para ler o arquivo.")
        return []

    def analisar_tendencias(self, dados_historicos: List[Dict]) -> str:
        """
        Analisa tendencias baseadas em dados historicos (futuro).
        """
        if not self.enabled or not dados_historicos:
            return "Analise de tendencias indisponivel."

        # Implementacao futura para analise historica
        return "Tendencias serao analisadas em breve."
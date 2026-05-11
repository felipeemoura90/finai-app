import os
import json
import re
import google.generativeai as genai
from typing import Dict, List, Optional
from pydantic import BaseModel, Field
from config import settings

class CategoriaTransacao(BaseModel):
    name: str = Field(description="Nome limpo da transacao (max 25 chars)")
    categoria: str = Field(description="Uma das categorias: Mercado, Alimentação, Moradia, Utilidades (Água/Luz/Tel), Assinaturas, Saúde, Transporte, Educação, Lazer, Transferência, Serviços, Outros")
    icon: str = Field(description="Icone do Material Design: shopping_cart, restaurant, home, electrical_services, subscriptions, local_pharmacy, local_gas_station, school, beach_access, compare_arrows, build, help_outline")

class TransacaoExtraida(BaseModel):
    data: str = Field(description="Data da transação no formato YYYY-MM-DD")
    valor: float = Field(description="Valor numérico da transação (use negativo para saídas e positivo para entradas)")
    descricao_original: str = Field(description="O texto exato e feio que veio no extrato")
    nome_limpo: str = Field(description="Nome fantasia real da loja ou serviço")
    categoria_sugerida: str = Field(description="Escolha APENAS entre: Mercado, Alimentação, Moradia, Utilidades (Água/Luz/Tel), Assinaturas, Saúde, Transporte, Educação, Lazer, Transferências, Serviços, ou Outros")
    fitid: str = Field(description="O código único da transação que está na tag <FITID> correspondente")

class ListaTransacoes(BaseModel):
    transacoes: List[TransacaoExtraida]

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
"""

        # Tenta Groq primeiro
        groq_key = settings.GROQ_API_KEY
        if groq_key:
            try:
                from groq import Groq
                client = Groq(api_key=groq_key)
                response = client.chat.completions.create(
                    model="llama-3.3-70b-versatile",
                    messages=[
                        {"role": "system", "content": "Voce categoriza transacoes financeiras."},
                        {"role": "user", "content": prompt},
                    ],
                    tools=[{
                        "type": "function",
                        "function": {
                            "name": "categorizar",
                            "description": "Categoriza a transacao financeira",
                            "parameters": CategoriaTransacao.model_json_schema()
                        }
                    }],
                    tool_choice={"type": "function", "function": {"name": "categorizar"}},
                    temperature=0.1,
                    max_tokens=150,
                )
                
                tool_call = response.choices[0].message.tool_calls[0]
                result = json.loads(tool_call.function.arguments)
                
                result["name"] = result.get("name", fallback["name"])[:25]
                result["categoria"] = result.get("categoria", fallback["categoria"])
                result["icon"] = result.get("icon", fallback["icon"])
                return result
            except Exception as e:
                print(f"[WARNING] Groq categorizacao falhou: {e}")

        # Fallback: Gemini
        if self.enabled:
            try:
                response = self.model.generate_content(
                    prompt,
                    generation_config=genai.GenerationConfig(
                        response_mime_type="application/json",
                        response_schema=CategoriaTransacao,
                    )
                )
                result = json.loads(response.text)
                
                result["name"] = result.get("name", fallback["name"])[:25]
                result["categoria"] = result.get("categoria", fallback["categoria"])
                result["icon"] = result.get("icon", fallback["icon"])
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

        categorias_texto = "\n".join([
            f"- {cat['nome']}: R$ {cat['valor']:.2f}"
            for cat in categorias[:5]
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
                return insight
            except Exception as e:
                print(f"[WARNING] Groq insight falhou: {e}")

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

    def extrair_transacoes_do_arquivo(self, texto_bruto: str) -> List[Dict]:
        """
        Extrai transacoes de um arquivo usando Groq (Llama) como motor principal
        e Gemini como fallback.
        """
        import re
        texto_limpo = re.sub(r'<[^>]+>', ' ', texto_bruto)
        texto_limpo = re.sub(r'\s+', ' ', texto_limpo).strip()
        texto_cortado = texto_limpo[:8000]
        
        prompt = f"""
        Você é um analista financeiro especialista em limpar e organizar extratos bancários brasileiros.
        Leia o texto bruto do extrato abaixo e extraia todas as transações financeiras.
        
        TEXTO BRUTO DO EXTRATO:
        {texto_cortado}
        """

        groq_key = settings.GROQ_API_KEY
        if groq_key:
            try:
                from groq import Groq
                print(f"[INFO] Usando Groq para ler o extrato ({len(texto_cortado)} chars)...")
                client = Groq(api_key=groq_key)
                
                response = client.chat.completions.create(
                    model="llama-3.3-70b-versatile",
                    messages=[
                        {"role": "system", "content": "Voce e um assistente financeiro que extrai transacoes."},
                        {"role": "user", "content": prompt},
                    ],
                    tools=[{
                        "type": "function",
                        "function": {
                            "name": "extrair",
                            "description": "Extrai transacoes financeiras do extrato",
                            "parameters": ListaTransacoes.model_json_schema()
                        }
                    }],
                    tool_choice={"type": "function", "function": {"name": "extrair"}},
                    temperature=0.1,
                    max_tokens=4000,
                )
                
                tool_call = response.choices[0].message.tool_calls[0]
                parsed = json.loads(tool_call.function.arguments)
                transacoes = parsed.get("transacoes", [])
                
                print(f"[OK] Groq extraiu {len(transacoes)} transacoes com sucesso!")
                return transacoes
                
            except Exception as e:
                print(f"[WARNING] Groq falhou: {e}. Tentando Gemini...")

        if self.enabled:
            try:
                print("[INFO] Usando Gemini como fallback para ler o extrato...")
                response = self.model.generate_content(
                    prompt,
                    generation_config=genai.GenerationConfig(
                        response_mime_type="application/json",
                        response_schema=ListaTransacoes,
                    )
                )
                parsed = json.loads(response.text)
                transacoes = parsed.get("transacoes", [])
                print(f"[OK] Gemini extraiu {len(transacoes)} transacoes com sucesso!")
                return transacoes
            except Exception as e:
                print(f"[ERROR] Gemini tambem falhou: {e}")

        print("[ERROR] Nenhuma IA disponivel para ler o arquivo.")
        return []

    def analisar_tendencias(self, dados_historicos: List[Dict]) -> str:
        if not self.enabled or not dados_historicos:
            return "Analise de tendencias indisponivel."
        return "Tendencias serao analisadas em breve."

def obter_resposta_chat(self, mensagem: str) -> str:
        """Processa a mensagem do utilizador e devolve a resposta da IA"""
        if not self.enabled:
            return "A funcionalidade de chat está desativada temporariamente."

        # Tenta Groq primeiro
        groq_key = settings.GROQ_API_KEY
        if groq_key:
            try:
                from groq import Groq
                client = Groq(api_key=groq_key)
                response = client.chat.completions.create(
                    model="llama-3.3-70b-versatile",
                    messages=[
                        {"role": "system", "content": "Você é o FinChat, um assistente financeiro amigável. Responda de forma curta e útil em português."},
                        {"role": "user", "content": mensagem},
                    ],
                    temperature=0.7,
                    max_tokens=200,
                )
                return response.choices[0].message.content.strip()
            except Exception as e:
                print(f"[WARNING] Groq chat falhou: {e}")

        # Fallback: Gemini
        try:
            response = self.model.generate_content(
                f"Você é o FinChat, um assistente financeiro amigável. Responda de forma curta em português à seguinte mensagem: {mensagem}"
            )
            return response.text.strip()
        except Exception as e:
            print(f"[ERROR] Erro na IA (Chat): {e}")
            raise ValueError("Lamento, ocorreu um erro ao tentar processar a sua mensagem.")
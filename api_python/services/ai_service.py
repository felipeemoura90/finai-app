import os
import json
import google.generativeai as genai
from typing import Dict, List, Optional
from dotenv import load_dotenv

# Carregar variáveis de ambiente
env_path = os.path.join(os.path.dirname(__file__), '..', '.env')
print(f"[INFO] Procurando .env em: {env_path}")
print(f"[INFO] Arquivo .env existe: {os.path.exists(env_path)}")

# Limpar variável existente antes de carregar
if 'GEMINI_API_KEY' in os.environ:
    del os.environ['GEMINI_API_KEY']

load_dotenv(dotenv_path=env_path, override=True)
print(f"[INFO] Arquivo .env carregado. GEMINI_API_KEY presente: {'GEMINI_API_KEY' in os.environ}")
if 'GEMINI_API_KEY' in os.environ:
    print(f"[INFO] Valor no os.environ: {os.environ['GEMINI_API_KEY'][:20]}...")

class AIService:
    def __init__(self, api_key: Optional[str] = None):
        # Configurar a chave da API
        self.api_key = api_key or os.getenv('GEMINI_API_KEY')
        print(f"[INFO] Chave API final: {self.api_key[:20]}..." if self.api_key else "[ERROR] Nenhuma chave encontrada")
        if not self.api_key:
            print("[WARNING] GEMINI_API_KEY nao encontrada. IA desabilitada.")
            self.enabled = False
            return

        print(f"[INFO] Chave API carregada: {self.api_key[:20]}...")
        genai.configure(api_key=self.api_key)
        self.model = genai.GenerativeModel('gemini-1.5-flash-latest')
        self.enabled = True
        print("[OK] IA Gemini conectada com sucesso!")

    def categorizar_transacao(self, texto_bruto: str) -> Dict[str, str]:
        """
        Usa IA para categorizar uma transação desconhecida.
        Retorna: {"name": str, "categoria": str, "icon": str}
        """
        if not self.enabled:
            return {
                "name": texto_bruto[:25].title(),
                "categoria": "Outros",
                "icon": "help_outline"
            }

        prompt = f"""
        Analise esta transação bancária e categorize-a adequadamente.

        Transação: "{texto_bruto}"

        Retorne APENAS um JSON válido no formato:
        {{
            "name": "Nome limpo da transação (máx 25 chars)",
            "categoria": "Uma das categorias: Mercado, Alimentação, Contas Fixas, Saúde, Transporte, Educação, Transferência, Serviços, Outros",
            "icon": "Ícone do Material Design: shopping_cart, restaurant, bolt, wifi, local_pharmacy, local_gas_station, school, compare_arrows, help_outline, payment, local_cafe"
        }}

        Seja específico e preciso. Use apenas as categorias listadas.
        """

        try:
            response = self.model.generate_content(prompt)
            result = json.loads(response.text.strip())

            # Validar campos obrigatórios
            result["name"] = result.get("name", texto_bruto[:25].title())[:25]
            result["categoria"] = result.get("categoria", "Outros")
            result["icon"] = result.get("icon", "help_outline")

            return result

        except Exception as e:
            print(f"❌ Erro na IA: {e}")
            return {
                "name": texto_bruto[:25].title(),
                "categoria": "Outros",
                "icon": "help_outline"
            }

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

        prompt = f"""
        Analise estes dados financeiros do mês e gere um insight personalizado e útil.

        Dados do mês:
        - Ganhos: R$ {ganhos:.2f}
        - Gastos: R$ {gastos:.2f}
        - Saldo: R$ {saldo:.2f}
        - Meta mensal: R$ {meta:.2f}

        Principais categorias de gasto:
        {categorias_texto}

        Escreva um parágrafo curto (máx 100 palavras) com:
        1. Uma observação positiva sobre os ganhos/gastos
        2. Uma dica específica baseada nos dados
        3. Uma sugestão prática para o próximo mês

        Seja amigável, use o nome "Felipe" e seja direto ao ponto.
        """

        try:
            print(f"[INFO] Gerando insight com IA para dados: ganhos={ganhos:.2f}, gastos={gastos:.2f}, saldo={saldo:.2f}")
            response = self.model.generate_content(prompt)
            insight = response.text.strip()
            print(f"[OK] Insight gerado pela IA: {insight[:50]}...")

            # Limitar tamanho se necessário
            if len(insight) > 200:
                insight = insight[:200] + "..."

            return insight

        except Exception as e:
            print(f"[ERROR] Erro gerando insight: {e}")
            print(f"[INFO] Retornando insight padrao")
            return f"Seu saldo do mes foi de R$ {saldo:.2f}. Mantenha o controle dos gastos!"

    def analisar_tendencias(self, dados_historicos: List[Dict]) -> str:
        """
        Analisa tendências baseadas em dados históricos (futuro).
        """
        if not self.enabled or not dados_historicos:
            return "Análise de tendências indisponível."

        # Implementação futura para análise histórica
        return "Tendências serão analisadas em breve."
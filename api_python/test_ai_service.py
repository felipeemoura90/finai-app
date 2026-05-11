import asyncio
import os
from config import settings
from services.ai_service import AIService
from dotenv import load_dotenv

load_dotenv()

def test_ai_service():
    service = AIService()
    
    # Test categorizar (Groq should be used since GROQ_API_KEY is present)
    print("Testing categorizar_transacao...")
    result_cat = service.categorizar_transacao("UBER *TRIP")
    print(result_cat)
    
    # Test extrair
    print("\nTesting extrair_transacoes_do_arquivo...")
    fake_extrato = "12/03/2023 - PGT IFOOD - -45.90\n<FITID>123456</FITID>"
    result_ext = service.extrair_transacoes_do_arquivo(fake_extrato)
    print(result_ext)

if __name__ == "__main__":
    test_ai_service()

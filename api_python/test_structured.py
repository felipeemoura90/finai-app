import asyncio
import json
import os
from pydantic import BaseModel, Field
from typing import List
import google.generativeai as genai
from groq import Groq
from dotenv import load_dotenv

load_dotenv("d:/Users/felipemoura/Desktop/script/Felipe_app/api_python/.env")

class CategoriaTransacao(BaseModel):
    name: str = Field(description="Nome limpo da transacao (max 25 chars)")
    categoria: str = Field(description="Uma das categorias: Mercado, Alimentação, Moradia, Utilidades (Água/Luz/Tel), Assinaturas, Saúde, Transporte, Educação, Lazer, Transferência, Serviços, Outros")
    icon: str = Field(description="Icone do Material Design")

def test_gemini():
    genai.configure(api_key=os.environ["GEMINI_API_KEY"])
    model = genai.GenerativeModel('gemini-1.5-flash')
    response = model.generate_content(
        "Analise a transacao: 'UBER *TRIP'",
        generation_config=genai.GenerationConfig(
            response_mime_type="application/json",
            response_schema=CategoriaTransacao,
        )
    )
    print("Gemini:", response.text)

def test_groq():
    client = Groq(api_key=os.environ["GROQ_API_KEY"])
    
    schema = CategoriaTransacao.model_json_schema()
    
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[
            {"role": "user", "content": "Analise a transacao: 'UBER *TRIP'"}
        ],
        tools=[{
            "type": "function",
            "function": {
                "name": "categorizar",
                "description": "Categoriza a transacao financeira",
                "parameters": schema
            }
        }],
        tool_choice={"type": "function", "function": {"name": "categorizar"}},
        temperature=0.1,
    )
    
    args = response.choices[0].message.tool_calls[0].function.arguments
    print("Groq:", args)

if __name__ == "__main__":
    test_gemini()
    test_groq()

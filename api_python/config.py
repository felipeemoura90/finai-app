import os
from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str

    # Chave JWT do Supabase para validação offline de tokens.
    # Encontre em: Supabase Dashboard > Project Settings > API > JWT Secret
    SUPABASE_JWT_SECRET: str

    GEMINI_API_KEY: Optional[str] = None
    GROQ_API_KEY: Optional[str] = None

    # Em produção, substitua com a URL real do seu frontend.
    # Exemplo: ORIGINS=["https://meufinai.com"]
    ORIGINS: List[str] = ['http://localhost:3000', 'http://127.0.0.1:3000']
    TRUSTED_HOSTS: List[str] = ['localhost', '127.0.0.1']

    APP_TITLE: str = 'FinAI API Engine'
    APP_VERSION: str = '0.1.0'
    DEFAULT_MONTH: str = "2026-04"
    DEFAULT_META: float = 3000.00

    model_config = SettingsConfigDict(env_file='.env', env_file_encoding='utf-8')


settings = Settings()

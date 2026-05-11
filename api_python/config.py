import os
from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    JWT_SECRET: Optional[str] = None
    GEMINI_API_KEY: Optional[str] = None
    GROQ_API_KEY: Optional[str] = None
    ORIGINS: List[str] = ['*']
    TRUSTED_HOSTS: List[str] = ['*']
    APP_TITLE: str = 'FinAI API Engine'
    APP_VERSION: str = '0.1.0'
    DEFAULT_MONTH: str = "2026-04"
    DEFAULT_META: float = 3000.00

    model_config = SettingsConfigDict(env_file='.env', env_file_encoding='utf-8', extra='ignore')


settings = Settings()

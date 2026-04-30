import os
from typing import List, Optional
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    JWT_SECRET: str = os.getenv('JWT_SECRET', None)
    GEMINI_API_KEY: Optional[str] = None
    ORIGINS: List[str] = ['*']
    TRUSTED_HOSTS: List[str] = ['*']
    APP_TITLE: str = 'FinAI API Engine'
    APP_VERSION: str = '0.1.0'

    class Config:
        env_file = '.env'
        env_file_encoding = 'utf-8'


settings = Settings()

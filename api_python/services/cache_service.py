import json
import redis
from typing import Optional, Any
from config import settings

class CacheService:
    def __init__(self):
        # Em produção, usaremos a URL real do Redis. Localmente, ele busca na porta padrão.
        redis_url = getattr(settings, 'REDIS_URL', 'redis://localhost:6379/0')
        try:
            # decode_responses=True já transforma os bytes em string automaticamente
            self.redis_client = redis.from_url(redis_url, decode_responses=True)
            # Testa a conexão
            self.redis_client.ping()
            print("[OK] Conectado ao Redis com sucesso!")
        except Exception as e:
            print(f"[AVISO] Não foi possível conectar ao Redis. Cache desativado. Erro: {e}")
            self.redis_client = None

    def get(self, key: str) -> Optional[Any]:
        """Busca um dado no cache"""
        if not self.redis_client: 
            return None
            
        data = self.redis_client.get(key)
        if data:
            return json.loads(data)
        return None

    def set(self, key: str, value: Any, expire_seconds: int = 3600):
        """Salva um dado no cache por um tempo determinado (padrão: 1 hora)"""
        if not self.redis_client: 
            return
            
        self.redis_client.setex(key, expire_seconds, json.dumps(value))

    def invalidate_user_cache(self, user_id: str):
        """Limpa todos os caches de um usuário específico (quando ele faz upload ou altera regra)"""
        if not self.redis_client: 
            return
            
        # Busca todas as chaves que começam com o ID do usuário
        keys = self.redis_client.keys(f"user:{user_id}:*")
        if keys:
            self.redis_client.delete(*keys)
            print(f"[CACHE] {len(keys)} registros invalidados para o usuário {user_id}")
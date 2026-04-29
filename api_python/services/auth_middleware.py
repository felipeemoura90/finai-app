from fastapi import Request, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import Optional
from services.auth_service import AuthService

security = HTTPBearer()

class AuthMiddleware:
    def __init__(self):
        self.auth_service = AuthService()

    async def __call__(self, request: Request, credentials: HTTPAuthorizationCredentials = Depends(security)):
        token = credentials.credentials
        user = self.auth_service.get_current_user(token)

        if not user:
            raise HTTPException(status_code=401, detail="Token inválido ou expirado")

        # Adiciona usuário ao request state
        request.state.user = user
        return user

# Instância global do middleware
auth_middleware = AuthMiddleware()

# Dependência para rotas protegidas
async def get_current_user(request: Request) -> dict:
    """Dependência para obter usuário atual em rotas protegidas"""
    return request.state.user
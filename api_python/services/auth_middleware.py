from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from services.auth_service import AuthService

security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    token = credentials.credentials
    auth_service = AuthService()
    user = auth_service.get_current_user(token)
    if not user:
        raise HTTPException(status_code=401, detail='Token inválido ou expirado')
    return user


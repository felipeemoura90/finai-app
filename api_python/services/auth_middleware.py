from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import httpx
from config import settings

security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    token = credentials.credentials
    
    # Valida o token chamando a API do Supabase diretamente (sem set_session)
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{settings.SUPABASE_URL}/auth/v1/user",
                headers={
                    "apikey": settings.SUPABASE_ANON_KEY,
                    "Authorization": f"Bearer {token}",
                },
                timeout=10.0,
            )
        
        if response.status_code != 200:
            raise HTTPException(status_code=401, detail='Token inválido ou expirado')
        
        user_data = response.json()
        return {
            'id': user_data.get('id'),
            'email': user_data.get('email'),
            'user_metadata': user_data.get('user_metadata', {}),
            'token': token
        }
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=401, detail='Falha ao validar token')

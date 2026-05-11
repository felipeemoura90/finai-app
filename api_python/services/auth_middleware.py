from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from jwt.exceptions import InvalidTokenError, ExpiredSignatureError
from config import settings

security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    """
    Valida o JWT do Supabase de forma local (offline), sem chamadas HTTP externas.
    Usa a SUPABASE_JWT_SECRET para verificar a assinatura criptograficamente.
    Isso elimina a latência de uma chamada de rede por request.
    """
    token = credentials.credentials

    try:
        payload = jwt.decode(
            token,
            settings.SUPABASE_JWT_SECRET,
            algorithms=["HS256"],
            # O Supabase usa "authenticated" como audience em tokens de usuário
            options={"verify_aud": False},
        )

        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=401, detail="Token inválido: campo 'sub' ausente")

        return {
            "id": user_id,
            "email": payload.get("email", ""),
            "user_metadata": payload.get("user_metadata", {}),
            "token": token,
        }

    except ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expirado. Faça login novamente.")
    except InvalidTokenError as e:
        raise HTTPException(status_code=401, detail=f"Token inválido: {str(e)}")
    except Exception:
        raise HTTPException(status_code=401, detail="Falha ao validar token")

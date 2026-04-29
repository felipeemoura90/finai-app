from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import HTTPBearer
from pydantic import BaseModel
from typing import Optional
from services.auth_service import AuthService
from services.auth_middleware import get_current_user

class AuthRequest(BaseModel):
    code: str
    code_verifier: str
    redirect_uri: str

class RefreshRequest(BaseModel):
    refresh_token: str

class UserResponse(BaseModel):
    id: str
    email: Optional[str]
    user_metadata: Optional[dict]

class AuthResponse(BaseModel):
    access_token: str
    refresh_token: str
    user: UserResponse

class AuthURLResponse(BaseModel):
    auth_url: str
    code_verifier: str

# Inicializa o router
router = APIRouter(prefix="/auth", tags=["auth"])

# Inicializa serviço de auth
auth_service = AuthService()
security = HTTPBearer()

@router.get("/url", response_model=AuthURLResponse)
def get_auth_url(redirect_uri: str = "http://localhost:8080/auth/callback"):
    """Gera URL de autenticação com PKCE"""
    try:
        result = auth_service.get_auth_url(redirect_uri)
        return AuthURLResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao gerar URL de auth: {str(e)}")

@router.post("/callback", response_model=AuthResponse)
def auth_callback(request: AuthRequest):
    """Troca código de autorização por tokens de acesso"""
    try:
        session = auth_service.exchange_code_for_session(
            request.code,
            request.code_verifier,
            request.redirect_uri
        )
        return AuthResponse(**session)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Erro na autenticação: {str(e)}")

@router.post("/refresh", response_model=AuthResponse)
def refresh_token(request: RefreshRequest):
    """Renova tokens usando refresh token"""
    try:
        session = auth_service.refresh_session(request.refresh_token)
        return AuthResponse(**session)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Erro ao renovar token: {str(e)}")

@router.get("/me", response_model=UserResponse)
def get_current_user_info(current_user: dict = Depends(get_current_user)):
    """Obtém informações do usuário atual"""
    return UserResponse(**current_user)

@router.post("/logout")
def logout(current_user: dict = Depends(get_current_user)):
    """Faz logout do usuário"""
    # Como estamos usando stateless JWT, o logout é principalmente informativo
    # O cliente deve remover os tokens localmente
    return {"message": "Logout realizado com sucesso"}
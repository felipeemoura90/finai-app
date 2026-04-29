import os
import secrets
import hashlib
import base64
from typing import Optional, Dict, Any
from datetime import datetime, timedelta
from jose import JWTError, jwt
from supabase_auth import SyncGoTrueClient
from dotenv import load_dotenv

load_dotenv()

class AuthService:
    def __init__(self):
        self.supabase_url = os.getenv('SUPABASE_URL')
        self.supabase_key = os.getenv('SUPABASE_ANON_KEY')
        self.jwt_secret = os.getenv('JWT_SECRET', secrets.token_hex(32))
        self.jwt_algorithm = "HS256"

        if not self.supabase_url or not self.supabase_key:
            raise ValueError("SUPABASE_URL e SUPABASE_ANON_KEY são obrigatórios")

        # Usar apenas o cliente de autenticação
        self.auth_client = SyncGoTrueClient(
            url=f"{self.supabase_url}/auth/v1",
            headers={"apikey": self.supabase_key}
        )

    def generate_pkce_challenge(self) -> Dict[str, str]:
        """Gera code_verifier e code_challenge para PKCE"""
        code_verifier = secrets.token_urlsafe(32)
        code_challenge = base64.urlsafe_b64encode(
            hashlib.sha256(code_verifier.encode()).digest()
        ).decode().rstrip('=')

        return {
            'code_verifier': code_verifier,
            'code_challenge': code_challenge
        }

    def create_access_token(self, data: dict, expires_delta: Optional[timedelta] = None):
        """Cria token JWT de acesso"""
        to_encode = data.copy()
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(minutes=15)
        to_encode.update({"exp": expire})
        encoded_jwt = jwt.encode(to_encode, self.jwt_secret, algorithm=self.jwt_algorithm)
        return encoded_jwt

    def verify_token(self, token: str) -> Optional[Dict[str, Any]]:
        """Verifica e decodifica token JWT"""
        try:
            payload = jwt.decode(token, self.jwt_secret, algorithms=[self.jwt_algorithm])
            return payload
        except JWTError:
            return None

    def get_auth_url(self, redirect_uri: str) -> Dict[str, str]:
        """Gera URL de autenticação com PKCE"""
        pkce = self.generate_pkce_challenge()

        auth_url = f"{self.supabase_url}/auth/v1/authorize?response_type=code&client_id={self.supabase_key}&redirect_uri={redirect_uri}&code_challenge={pkce['code_challenge']}&code_challenge_method=S256"

        return {
            'auth_url': auth_url,
            'code_verifier': pkce['code_verifier']
        }

    def exchange_code_for_session(self, code: str, code_verifier: str, redirect_uri: str) -> Dict[str, Any]:
        """Troca código de autorização por sessão"""
        try:
            response = self.auth_client.exchange_code_for_session(
                auth_code=code,
                code_verifier=code_verifier,
                redirect_uri=redirect_uri
            )
            return {
                'access_token': response.access_token,
                'refresh_token': response.refresh_token,
                'user': {
                    'id': response.user.id,
                    'email': response.user.email,
                    'user_metadata': response.user.user_metadata
                }
            }
        except Exception as e:
            raise Exception(f"Erro na troca de código: {str(e)}")

    def refresh_session(self, refresh_token: str) -> Dict[str, Any]:
        """Renova sessão usando refresh token"""
        try:
            response = self.auth_client.refresh_session(refresh_token)
            return {
                'access_token': response.access_token,
                'refresh_token': response.refresh_token,
                'user': {
                    'id': response.user.id,
                    'email': response.user.email,
                    'user_metadata': response.user.user_metadata
                }
            }
        except Exception as e:
            raise Exception(f"Erro ao renovar sessão: {str(e)}")

    def get_current_user(self, access_token: str) -> Optional[Dict[str, Any]]:
        """Obtém usuário atual"""
        try:
            # Define o token de acesso para requests subsequentes
            self.auth_client.set_session(access_token, "")
            user = self.auth_client.get_user()
            return {
                'id': user.user.id,
                'email': user.user.email,
                'user_metadata': user.user.user_metadata
            }
        except Exception:
            return None

    def sign_out(self, access_token: str) -> bool:
        """Faz logout do usuário"""
        try:
            self.auth_client.set_session(access_token, "")
            self.auth_client.sign_out()
            return True
        except Exception:
            return False
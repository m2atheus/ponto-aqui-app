"""Redefine somente a conta mobile de teste apos autenticacao HTTP real do RH."""
import argparse
import json
import logging
from pathlib import Path
import sys
from uuid import UUID


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--backend-root", required=True)
    args = parser.parse_args()
    backend = Path(args.backend_root).resolve()
    if not (backend / "app" / "__init__.py").is_file():
        raise ValueError("Backend ausente")
    data = json.load(sys.stdin)
    company_id = UUID(data["empresa_id"])
    user_id = UUID(data["usuario_id"])
    email = data["email"]
    password = data["nova_senha"]
    token = data["access_token"]
    if (not isinstance(email, str) or not email.startswith("mobile.teste.")
            or not email.endswith("@example.invalid")
            or not isinstance(password, str) or not 20 <= len(password) <= 1024
            or not isinstance(token, str) or not token or any(c.isspace() for c in token)):
        raise ValueError("Contexto invalido")
    sys.path.insert(0, str(backend))
    logging.disable(logging.CRITICAL)
    from flask_jwt_extended import get_jwt, get_jwt_identity, verify_jwt_in_request
    from sqlalchemy import select
    from app import create_app, db
    from app.models import PapelUsuario, Usuarios
    from app.services.auth_service import AuthService

    application = create_app()
    with application.app_context(), application.test_request_context(
        headers={"Authorization": "Bearer " + token}
    ):
        verify_jwt_in_request()
        claims = get_jwt()
        if UUID(claims["empresa_id"]) != company_id or claims.get("role") != "RH":
            raise ValueError("RH da empresa necessario")
        profile, status = AuthService.me(get_jwt_identity(), claims)
        if (status != 200 or profile["usuario"]["papel"] != "RH"
                or UUID(profile["usuario"]["empresa_id"]) != company_id):
            raise ValueError("RH inativo")
        user = db.session.scalar(select(Usuarios).where(
            Usuarios.id == user_id, Usuarios.empresa_id == company_id,
            Usuarios.email == email, Usuarios.ativo.is_(True),
        ).with_for_update())
        if (user is None or user.papel != PapelUsuario.FUNCIONARIO
                or not user.nome.startswith("Teste Mobile ")):
            raise ValueError("Conta de teste incompatível")
        user.senha_hash = AuthService.hash_senha(password)
        db.session.commit()
    return {"ok": True, "usuario_id": str(user_id)}


if __name__ == "__main__":
    try:
        result, code = main(), 0
    except Exception:
        result, code = {"ok": False, "erro": "Redefinicao nao confirmada; confira o contexto RH e da conta de teste."}, 1
    print(json.dumps(result, ensure_ascii=True))
    sys.exit(code)

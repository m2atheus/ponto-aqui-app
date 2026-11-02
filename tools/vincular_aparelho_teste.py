"""Provisiona somente o aparelho de uma conta de teste autenticada pela API.

Entrada JSON por stdin: token real emitido pela API, IDs e UUID da instalacao.
Nao cria contas, nao fabrica JWT, nao imprime credenciais e nao faz migrations.
"""

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
        raise ValueError("Backend nao encontrado.")
    data = json.load(sys.stdin)
    user_id = UUID(data["usuario_id"])
    company_id = UUID(data["empresa_id"])
    device_uuid = UUID(data["device_uuid"])
    token = data["access_token"]
    if not isinstance(token, str) or not token or any(c.isspace() for c in token):
        raise ValueError("Sessao de teste invalida.")

    sys.path.insert(0, str(backend))
    logging.disable(logging.CRITICAL)
    from flask_jwt_extended import get_jwt, get_jwt_identity, verify_jwt_in_request
    from sqlalchemy import select
    from app import create_app, db
    from app.models import Dispositivos, PapelUsuario, Usuarios
    from app.services.device_service import DeviceService

    # Usa a factory normal do backend sem ler/exibir arquivos de credenciais.
    application = create_app()
    with application.app_context(), application.test_request_context(
        headers={"Authorization": "Bearer " + token}
    ):
        # O token veio do login HTTP real. Conferir a assinatura tambem comprova
        # que esta factory e o servidor aberto usam o mesmo contexto JWT.
        verify_jwt_in_request()
        claims = get_jwt()
        if (UUID(get_jwt_identity()) != user_id
                or UUID(claims["empresa_id"]) != company_id
                or claims.get("role") != "FUNCIONARIO"):
            raise ValueError("Contexto de teste incompatível.")
        user = db.session.execute(select(Usuarios.email, Usuarios.nome, Usuarios.papel).where(
            Usuarios.id == user_id, Usuarios.empresa_id == company_id,
            Usuarios.ativo.is_(True),
        )).one_or_none()
        if (user is None or user.papel != PapelUsuario.FUNCIONARIO
                or not user.nome.startswith("Teste Mobile ")
                or not user.email.endswith("@example.invalid")):
            raise ValueError("A operacao aceita somente a nova conta de teste.")
        others = db.session.scalar(select(Dispositivos.id).where(
            Dispositivos.empresa_id == company_id, Dispositivos.usuario_id == user_id,
            Dispositivos.ativo.is_(True), Dispositivos.device_uuid != device_uuid,
        ).limit(1))
        if others is not None:
            raise ValueError("A conta ja possui outro aparelho. Nenhum aparelho foi revogado.")
        result, status = DeviceService.registrar_login_pessoal(
            company_id, user_id, device_uuid, "Emulador - teste Ponto Aqui"
        )
        if status != 200:
            return {"ok": False, "erro": result["erro"]["mensagem"]}, 1
        device = result["dispositivo"]
        return {"ok": True, "dispositivo_id": device["id"], "device_uuid": device["device_uuid"]}, 0


if __name__ == "__main__":
    try:
        result, code = main()
    except Exception:
        # Nunca imprimir traceback com contexto de conexao/JWT/configuracao.
        result, code = {"ok": False, "erro": "Nao foi possivel provisionar o aparelho de teste. Nenhum contrato ou migration foi alterado."}, 1
    print(json.dumps(result, ensure_ascii=True))
    sys.exit(code)

"""Crea el primer administrador desde la terminal.

Uso (con Docker en marcha):
    docker compose exec api python -m app.crear_admin
"""
from getpass import getpass

from sqlalchemy import select

from app.core.security import hashear_password
from app.database import SessionLocal
from app.models import Rol, Usuario


def main():
    nombre = input("Nombre: ").strip()
    email = input("Email: ").strip().lower()
    password = getpass("Contraseña (mínimo 8 caracteres, no se ve al escribir): ")
    if len(password) < 8:
        print("La contraseña debe tener al menos 8 caracteres.")
        return
    with SessionLocal() as db:
        if db.scalar(select(Usuario).where(Usuario.email == email)):
            print("Ya existe un usuario con ese email.")
            return
        db.add(Usuario(nombre=nombre, email=email, password_hash=hashear_password(password), rol=Rol.ADMIN))
        db.commit()
    print(f"Administrador {email} creado correctamente.")


if __name__ == "__main__":
    main()

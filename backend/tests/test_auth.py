"""Pruebas de inicio de sesión y permisos de usuarios."""


def test_login_y_quien_soy(client, usuarios):
    r = client.get("/auth/yo", headers=usuarios["ana"]["h"])
    assert r.status_code == 200
    assert r.json()["rol"] == "tecnico"


def test_contrasena_incorrecta(client, usuarios):
    r = client.post("/auth/login", data={"username": "ana@prevenapp.es", "password": "mal"})
    assert r.status_code == 401


def test_sin_token(client):
    assert client.get("/auth/yo").status_code == 401


def test_solo_admin_crea_usuarios(client, usuarios):
    nuevo = {"nombre": "Pep", "email": "pep@prevenapp.es", "password": "clave1234"}
    assert client.post("/usuarios", json=nuevo, headers=usuarios["ana"]["h"]).status_code == 403
    r = client.post("/usuarios", json=nuevo, headers=usuarios["admin"]["h"])
    assert r.status_code == 201
    assert client.post("/usuarios", json=nuevo, headers=usuarios["admin"]["h"]).status_code == 409

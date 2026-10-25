"""Pruebas del flujo completo: contrato → pendientes → check → aviso → incentivos."""
import pytest


@pytest.fixture
def datos(client, usuarios):
    """Un tipo de actividad, un cliente de Ana con esa actividad en el contrato desde 2024."""
    admin = usuarios["admin"]["h"]
    tipo = client.post(
        "/tipos-actividad",
        json={"nombre": "Evaluación de riesgos"},  # 8 % por defecto
        headers=admin,
    ).json()
    ana = usuarios["ana"]["h"]
    cliente = client.post("/clientes", json={"nombre": "Panadería Sol"}, headers=ana).json()
    r = client.post(
        f"/clientes/{cliente['id']}/obligatorias",
        json={"tipo_actividad_id": tipo["id"], "desde_anio": 2024},
        headers=ana,
    )
    assert r.status_code == 201, r.text
    return {"tipo": tipo, "cliente": cliente}


def test_tecnico_solo_ve_sus_clientes(client, usuarios, datos):
    assert len(client.get("/clientes", headers=usuarios["ana"]["h"]).json()) == 1
    assert client.get("/clientes", headers=usuarios["luis"]["h"]).json() == []
    assert client.get(f"/clientes/{datos['cliente']['id']}", headers=usuarios["luis"]["h"]).status_code == 404
    assert len(client.get("/clientes", headers=usuarios["presupuestos"]["h"]).json()) == 1


def test_pendientes_de_anios_anteriores(client, usuarios, datos):
    r = client.get("/agenda/pendientes", headers=usuarios["ana"]["h"])
    assert r.status_code == 200
    p = r.json()
    # Contrato desde 2024 y hoy es 2026 → 2024, 2025 y 2026
    assert p["total"] == 3
    assert p["de_anios_anteriores"] == 2
    assert p["del_anio_actual"] == 1
    assert p["clientes_sin_visitar_anio_anterior"] == ["Panadería Sol"]
    assert [a["atrasada"] for a in p["actividades"]] == [True, True, False]
    # Volver a pedirlo no crea duplicados
    assert client.get("/agenda/pendientes", headers=usuarios["ana"]["h"]).json()["total"] == 3


def test_margen_de_cinco_anios(client, usuarios, datos):
    """Un contrato desde 2015 solo genera actividades de 2022 a 2026 (5 años)."""
    otro = client.post("/clientes", json={"nombre": "Taller Antiguo"}, headers=usuarios["ana"]["h"]).json()
    client.post(
        f"/clientes/{otro['id']}/obligatorias",
        json={"tipo_actividad_id": datos["tipo"]["id"], "desde_anio": 2015},
        headers=usuarios["ana"]["h"],
    )
    p = client.get("/agenda/pendientes", headers=usuarios["ana"]["h"]).json()
    anios = sorted(a["anio"] for a in p["actividades"] if a["cliente_nombre"] == "Taller Antiguo")
    assert anios == [2022, 2023, 2024, 2025, 2026]
    assert p["primer_anio_en_plazo"] == 2022


def test_check_aviso_e_incentivos(client, usuarios, datos, monkeypatch):
    enviados = []

    class SMTPFalso:
        def __init__(self, host, port, timeout):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return False

        def send_message(self, mensaje):
            enviados.append(mensaje)

    monkeypatch.setattr("app.services.avisos.settings.smtp_host", "smtp-falso")
    monkeypatch.setattr("app.services.avisos.smtplib.SMTP", SMTPFalso)

    ana = usuarios["ana"]["h"]
    pendientes = client.get("/agenda/pendientes", headers=ana).json()["actividades"]
    actividad = pendientes[-1]  # la de 2026

    # Programar fecha → pasa a "programada" y aparece en el calendario
    r = client.patch(f"/actividades/{actividad['id']}", json={"fecha_programada": "2026-10-20"}, headers=ana)
    assert r.json()["estado"] == "programada"
    agenda = client.get("/agenda", params={"desde": "2026-10-01", "hasta": "2026-10-31"}, headers=ana).json()
    assert [a["id"] for a in agenda["actividades"]] == [actividad["id"]]

    # Fecha futura no permitida
    r = client.post(
        f"/actividades/{actividad['id']}/realizar",
        json={"codigo_presupuesto": "P-2026-0458", "fecha_realizacion": "2026-12-01", "importe_presupuesto": 1250},
        headers=ana,
    )
    assert r.status_code == 400

    # El check: código de presupuesto + fecha
    r = client.post(
        f"/actividades/{actividad['id']}/realizar",
        json={"codigo_presupuesto": "P-2026-0458", "fecha_realizacion": "2026-10-20", "importe_presupuesto": 1250},
        headers=ana,
    )
    assert r.status_code == 200, r.text
    hecha = r.json()
    assert hecha["estado"] == "realizada"
    assert hecha["redactor_nombre"] == "Ana Técnica"
    assert hecha["captador_nombre"] == "Ana Técnica"  # por defecto, el técnico del cliente
    # 8 % de 1.250 € = 100 € para cada uno
    assert hecha["importe_redactor"] == 100 and hecha["importe_captador"] == 100
    assert hecha["importe_presupuesto"] == 1250

    # El aviso ha llegado a presupuestos con técnico, presupuesto y fecha
    assert len(enviados) == 1
    correo = enviados[0]
    assert correo["To"] == "presupuestos@prevenapp.es"
    texto = correo.get_content()
    assert "Ana Técnica" in texto and "P-2026-0458" in texto and "20/10/2026" in texto and "1250.00" in texto
    avisos = client.get("/avisos", headers=usuarios["presupuestos"]["h"]).json()
    assert avisos[0]["enviado"] is True

    # Doble check no permitido
    r = client.post(
        f"/actividades/{actividad['id']}/realizar",
        json={"codigo_presupuesto": "X", "fecha_realizacion": "2026-10-20", "importe_presupuesto": 10},
        headers=ana,
    )
    assert r.status_code == 409

    # Incentivos del 3.er cuatrimestre: 100 (captadora) + 100 (redactora)
    inc = client.get("/incentivos", headers=ana).json()
    assert inc["cuatrimestre"] == 3
    assert inc["como_captador"] == {"numero": 1, "total": 100.0}
    assert inc["como_redactor"] == {"numero": 1, "total": 100.0}
    assert inc["total"] == 200.0

    # Cambiar el porcentaje después no cambia lo ya calculado
    client.patch(f"/tipos-actividad/{datos['tipo']['id']}", json={"porcentaje_redactor": 50}, headers=usuarios["admin"]["h"])
    assert client.get("/incentivos", headers=ana).json()["total"] == 200.0

    # Historial: octubre tiene 1 actividad
    hist = client.get("/historial", headers=ana).json()
    assert hist["meses"][9]["realizadas_como_redactor"] == 1
    assert sum(m["realizadas_como_redactor"] for m in hist["meses"]) == 1

    # Pendientes: ya solo quedan las de 2024 y 2025
    assert client.get("/agenda/pendientes", headers=ana).json()["total"] == 2

    # Deshacer el check
    r = client.post(f"/actividades/{actividad['id']}/deshacer", headers=ana)
    assert r.json()["estado"] == "programada"
    assert client.get("/incentivos", headers=ana).json()["total"] == 0


def test_captador_y_redactor_distintos(client, usuarios, datos, monkeypatch):
    """Ana capta la actividad y Luis la realiza: cada uno cobra su parte."""
    ana, luis = usuarios["ana"], usuarios["luis"]
    extra = client.post(
        "/actividades",
        json={"cliente_id": datos["cliente"]["id"], "tipo_actividad_id": datos["tipo"]["id"], "redactor_id": luis["id"]},
        headers=ana["h"],
    ).json()
    # Luis puede verla porque es el redactor, aunque el cliente no sea suyo
    r = client.post(
        f"/actividades/{extra['id']}/realizar",
        json={"codigo_presupuesto": "P-1", "fecha_realizacion": "2026-09-15", "importe_presupuesto": 500},
        headers=luis["h"],
    )
    assert r.status_code == 200, r.text
    # 8 % de 500 € = 40 € para cada uno
    assert client.get("/incentivos", headers=ana["h"]).json()["total"] == 40.0
    assert client.get("/incentivos", headers=luis["h"]).json()["total"] == 40.0
    resumen = client.get("/incentivos/resumen", headers=usuarios["presupuestos"]["h"]).json()
    assert {t["tecnico_nombre"]: t["total"] for t in resumen} == {"Ana Técnica": 40.0, "Luis Técnico": 40.0}
    # Un técnico no puede ver los incentivos de otro ni el resumen
    assert client.get("/incentivos", params={"tecnico_id": ana["id"]}, headers=luis["h"]).status_code == 403
    assert client.get("/incentivos/resumen", headers=luis["h"]).status_code == 403


def test_aviso_sin_smtp_queda_registrado(client, usuarios, datos):
    ana = usuarios["ana"]["h"]
    actividad = client.get("/agenda/pendientes", headers=ana).json()["actividades"][0]
    r = client.post(
        f"/actividades/{actividad['id']}/realizar",
        json={"codigo_presupuesto": "P-2", "fecha_realizacion": "2026-10-01", "importe_presupuesto": 300},
        headers=ana,
    )
    assert r.status_code == 200  # la actividad se marca aunque no haya correo configurado
    aviso = client.get("/avisos", headers=usuarios["admin"]["h"]).json()[0]
    assert aviso["enviado"] is False and "SMTP" in aviso["error"]


def test_redondeo_y_importe_obligatorio(client, usuarios, datos):
    ana = usuarios["ana"]["h"]
    actividad = client.get("/agenda/pendientes", headers=ana).json()["actividades"][0]
    url = f"/actividades/{actividad['id']}/realizar"
    # Sin importe no se puede hacer el check
    assert client.post(url, json={"codigo_presupuesto": "P-3", "fecha_realizacion": "2026-10-01"}, headers=ana).status_code == 422
    # 8 % de 333,33 € = 26,6664 → 26,67 €
    r = client.post(url, json={"codigo_presupuesto": "P-3", "fecha_realizacion": "2026-10-01", "importe_presupuesto": 333.33}, headers=ana)
    assert r.json()["importe_redactor"] == 26.67


def test_lista_tecnicos_y_check_con_participantes(client, usuarios, datos):
    ana, luis = usuarios["ana"], usuarios["luis"]
    tecnicos = client.get("/tecnicos", headers=ana["h"]).json()
    assert [t["nombre"] for t in tecnicos] == ["Ana Técnica", "Luis Técnico"]
    actividad = client.get("/agenda/pendientes", headers=ana["h"]).json()["actividades"][0]
    # Ana hace el check indicando que Luis fue el captador
    r = client.post(
        f"/actividades/{actividad['id']}/realizar",
        json={
            "codigo_presupuesto": "P-9",
            "fecha_realizacion": "2026-10-01",
            "importe_presupuesto": 1000,
            "captador_id": luis["id"],
        },
        headers=ana["h"],
    ).json()
    assert r["captador_nombre"] == "Luis Técnico" and r["redactor_nombre"] == "Ana Técnica"
    assert client.get("/incentivos", headers=luis["h"]).json()["como_captador"]["total"] == 80.0
    # Un id que no es de un técnico se rechaza
    otra = client.get("/agenda/pendientes", headers=ana["h"]).json()["actividades"][0]
    r = client.post(
        f"/actividades/{otra['id']}/realizar",
        json={"codigo_presupuesto": "P-10", "fecha_realizacion": "2026-10-01", "importe_presupuesto": 10, "captador_id": 9999},
        headers=ana["h"],
    )
    assert r.status_code == 400


def test_guardias(client, usuarios):
    ana, luis = usuarios["ana"]["h"], usuarios["luis"]["h"]
    assert client.put("/guardias/2026-10-24", json={"guardia": True}, headers=ana).json()["guardia"] is True
    client.put("/guardias/2026-10-24", json={"guardia": True}, headers=ana)  # repetir no duplica
    de_guardia = client.get("/guardias/dia/2026-10-24", headers=luis).json()
    assert [u["nombre"] for u in de_guardia] == ["Ana Técnica"]
    assert client.get("/guardias", headers=ana).json() == ["2026-10-24"]
    agenda = client.get("/agenda", headers=ana).json()
    assert agenda["guardias"] == ["2026-10-24"]
    client.put("/guardias/2026-10-24", json={"guardia": False}, headers=ana)
    assert client.get("/guardias/dia/2026-10-24", headers=luis).json() == []
    # Un técnico no puede marcar guardias de otro
    r = client.put("/guardias/2026-10-25", json={"guardia": True, "tecnico_id": usuarios["ana"]["id"]}, headers=luis)
    assert r.status_code == 403


def test_carpetas_de_clientes(client, usuarios, datos, monkeypatch):
    """Cada cliente es una carpeta con su código y lo que le falta / tiene hecho."""
    monkeypatch.setattr("app.services.avisos.enviar_email", lambda *a, **k: None, raising=False)
    ana = usuarios["ana"]["h"]
    cliente_id = datos["cliente"]["id"]
    centro = client.get(f"/clientes/{cliente_id}/centros", headers=ana).json()[0]
    client.patch(f"/clientes/{cliente_id}/centros/{centro['id']}", json={"codigo": "10234", "cif": "B07000001"}, headers=ana)

    carpeta = client.get("/clientes", headers=ana).json()[0]
    # Contrato desde 2024 → le faltan 2024, 2025 y 2026; dos son de años anteriores
    assert (carpeta["faltan"], carpeta["atrasadas"], carpeta["hechas"]) == (3, 2, 0)

    # Se hace la de 2024 → le faltan 2 (una atrasada) y tiene 1 hecha
    actividad = next(a for a in client.get(f"/actividades?cliente_id={cliente_id}", headers=ana).json() if a["anio"] == 2024)
    r = client.post(
        f"/actividades/{actividad['id']}/realizar",
        json={"codigo_presupuesto": "P-1", "fecha_realizacion": "2026-03-02", "importe_presupuesto": 100},
        headers=ana,
    )
    assert r.status_code == 200, r.text
    carpeta = client.get("/clientes", headers=ana).json()[0]
    assert (carpeta["faltan"], carpeta["atrasadas"], carpeta["hechas"]) == (2, 1, 1)

    # Se puede buscar por código
    assert len(client.get("/clientes?buscar=1023", headers=ana).json()) == 1
    assert client.get("/clientes?buscar=999", headers=ana).json() == []


def test_centros_de_trabajo(client, usuarios, datos):
    """Cliente → centros: cada centro tiene su contrato y sus actividades."""
    ana = usuarios["ana"]["h"]
    cliente_id = datos["cliente"]["id"]
    # El cliente empieza con su "Centro principal", donde quedó el contrato de la prueba
    centros = client.get(f"/clientes/{cliente_id}/centros", headers=ana).json()
    assert [c["nombre"] for c in centros] == ["Centro principal"]
    assert centros[0]["faltan"] == 3

    # Un segundo centro con la misma actividad en su contrato desde 2026
    obrador = client.post(
        f"/clientes/{cliente_id}/centros", json={"nombre": "Obrador", "direccion": "Marratxí"}, headers=ana
    ).json()
    r = client.post(
        f"/clientes/{cliente_id}/obligatorias",
        json={"tipo_actividad_id": datos["tipo"]["id"], "centro_id": obrador["id"], "desde_anio": 2026},
        headers=ana,
    )
    assert r.status_code == 201, r.text
    # La misma actividad no se puede repetir en el mismo centro
    r = client.post(
        f"/clientes/{cliente_id}/obligatorias",
        json={"tipo_actividad_id": datos["tipo"]["id"], "centro_id": obrador["id"]},
        headers=ana,
    )
    assert r.status_code == 409

    centros = {c["nombre"]: c for c in client.get(f"/clientes/{cliente_id}/centros", headers=ana).json()}
    assert centros["Obrador"]["faltan"] == 1 and centros["Centro principal"]["faltan"] == 3
    carpeta = client.get("/clientes", headers=ana).json()[0]
    assert carpeta["num_centros"] == 2 and carpeta["faltan"] == 4

    del_obrador = client.get(f"/actividades?centro_id={obrador['id']}", headers=ana).json()
    assert len(del_obrador) == 1
    assert del_obrador[0]["centro_nombre"] == "Obrador"
    assert del_obrador[0]["cliente_direccion"] == "Marratxí"

    # Un centro de otro cliente no vale
    otro = client.post("/clientes", json={"nombre": "Otro"}, headers=ana).json()
    r = client.post(
        "/actividades",
        json={"cliente_id": otro["id"], "tipo_actividad_id": datos["tipo"]["id"], "centro_id": obrador["id"]},
        headers=ana,
    )
    assert r.status_code == 404


def test_sociedad_nueva_con_su_primer_centro(client, usuarios):
    ana = usuarios["ana"]["h"]
    sociedad = client.post(
        "/clientes",
        json={"nombre": "Grupo Sol S.L.", "centro_nombre": "Tienda Palma", "codigo": "20001", "cif": "B0700099", "direccion": "Palma"},
        headers=ana,
    )
    assert sociedad.status_code == 201, sociedad.text
    centros = client.get(f"/clientes/{sociedad.json()['id']}/centros", headers=ana).json()
    assert [(c["nombre"], c["codigo"], c["cif"], c["direccion"]) for c in centros] == [("Tienda Palma", "20001", "B0700099", "Palma")]
    # Se encuentra la sociedad buscando el nº de cliente o el CIF del centro
    assert len(client.get("/clientes?buscar=20001", headers=ana).json()) == 1
    assert len(client.get("/clientes?buscar=B0700099", headers=ana).json()) == 1


def test_cambiar_el_centro_de_una_actividad(client, usuarios, datos):
    """Se puede cambiar el centro de la visita; la actividad del contrato no se duplica."""
    ana = usuarios["ana"]["h"]
    cliente_id = datos["cliente"]["id"]
    otro = client.post(f"/clientes/{cliente_id}/centros", json={"nombre": "Obrador"}, headers=ana).json()
    client.get("/agenda/pendientes", headers=ana)  # crea las actividades del contrato
    actividad = client.get(f"/actividades?cliente_id={cliente_id}", headers=ana).json()[0]
    r = client.patch(f"/actividades/{actividad['id']}", json={"centro_id": otro["id"]}, headers=ana)
    assert r.status_code == 200 and r.json()["centro_nombre"] == "Obrador"
    # Al volver a generar no aparece otra igual en el centro de antes
    assert len(client.get(f"/actividades?cliente_id={cliente_id}", headers=ana).json()) == 3
    assert client.get("/agenda/pendientes", headers=ana).json()["total"] == 3
    # Un centro de otra sociedad no vale
    ajena = client.post("/clientes", json={"nombre": "Otra"}, headers=ana).json()
    centro_ajeno = client.get(f"/clientes/{ajena['id']}/centros", headers=ana).json()[0]
    r = client.patch(f"/actividades/{actividad['id']}", json={"centro_id": centro_ajeno["id"]}, headers=ana)
    assert r.status_code == 404

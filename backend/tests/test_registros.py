"""Pruebas de la hora y lugar de las visitas y del registro de km y formación."""
from tests.test_flujo import datos  # noqa: F401  (reutiliza los datos de prueba)


def test_visita_con_hora_y_lugar(client, usuarios, datos):  # noqa: F811
    ana = usuarios["ana"]["h"]
    actividad = client.get("/agenda/pendientes", headers=ana).json()["actividades"][-1]
    r = client.patch(
        f"/actividades/{actividad['id']}",
        json={"fecha_programada": "2026-10-28", "hora_programada": "09:30", "lugar": "Polígono Son Castelló, nave 4"},
        headers=ana,
    ).json()
    assert r["hora_programada"] == "09:30:00" and r["lugar"] == "Polígono Son Castelló, nave 4"
    agenda = client.get("/agenda", params={"desde": "2026-10-01", "hasta": "2026-10-31"}, headers=ana).json()
    assert agenda["actividades"][0]["hora_programada"] == "09:30:00"
    # Al quitar la fecha, se quita también la hora
    r = client.patch(f"/actividades/{actividad['id']}", json={"fecha_programada": None}, headers=ana).json()
    assert r["estado"] == "pendiente" and r["hora_programada"] is None


def test_registro_del_mes_y_exportar(client, usuarios):
    ana, luis = usuarios["ana"]["h"], usuarios["luis"]["h"]
    for cuerpo in [
        {"fecha": "2026-10-05", "tipo": "kilometros", "cantidad": 42.5, "concepto": "Palma → Inca"},
        {"fecha": "2026-10-05", "tipo": "kilometros", "cantidad": 12, "concepto": "Inca → Palma"},
        {"fecha": "2026-10-09", "tipo": "formacion", "cantidad": 3, "concepto": "Curso primeros auxilios", "turno": "tarde"},
        {"fecha": "2026-09-30", "tipo": "kilometros", "cantidad": 100},  # otro mes
    ]:
        assert client.post("/registros", json=cuerpo, headers=ana).status_code == 201

    mes = client.get("/registros", params={"anio": 2026, "mes": 10}, headers=ana).json()
    assert mes["total_km"] == 54.5
    assert mes["total_horas_formacion"] == 3
    assert mes["dias_con_registro"] == 2
    assert len(mes["registros"]) == 3

    # Luis no ve los registros de Ana ni puede borrarlos
    assert client.get("/registros", params={"anio": 2026, "mes": 10}, headers=luis).json()["registros"] == []
    id_ana = mes["registros"][0]["id"]
    assert client.delete(f"/registros/{id_ana}", headers=luis).status_code == 404
    # Pero presupuestos sí puede consultarlos
    r = client.get("/registros", params={"anio": 2026, "mes": 10, "tecnico_id": usuarios["ana"]["id"]}, headers=usuarios["presupuestos"]["h"])
    assert r.json()["total_km"] == 54.5

    # Exportar a CSV para Excel
    csv = client.get("/registros/exportar", params={"anio": 2026, "mes": 10}, headers=ana)
    assert csv.status_code == 200
    texto = csv.content.decode("utf-8-sig")
    assert "05/10/2026;Kilómetros;;42,50;km;Palma → Inca" in texto
    assert "TOTAL KM;;;;54,50;km" in texto
    assert "09/10/2026;Formación;Tarde;3,00;horas;Curso primeros auxilios" in texto
    assert mes["horas_por_turno"] == {"manana": 0, "tarde": 3, "extra_manana": 0, "extra_tarde": 0}
    # La formación necesita turno
    sin_turno = client.post("/registros", json={"fecha": "2026-10-09", "tipo": "formacion", "cantidad": 1}, headers=ana)
    assert sin_turno.status_code == 422

    # Borrar un registro
    assert client.delete(f"/registros/{id_ana}", headers=ana).status_code == 204
    assert client.get("/registros", params={"anio": 2026, "mes": 10}, headers=ana).json()["total_km"] == 12

    # Validaciones: día futuro y cantidad no válida
    assert client.post("/registros", json={"fecha": "2026-12-01", "tipo": "kilometros", "cantidad": 5}, headers=ana).status_code == 400
    assert client.post("/registros", json={"fecha": "2026-10-01", "tipo": "kilometros", "cantidad": 0}, headers=ana).status_code == 422


def test_check_apunta_km_y_formacion(client, usuarios, datos):  # noqa: F811
    ana = usuarios["ana"]["h"]
    actividad = client.get("/agenda/pendientes", headers=ana).json()["actividades"][0]
    r = client.post(
        f"/actividades/{actividad['id']}/realizar",
        json={
            "codigo_presupuesto": "P-20",
            "fecha_realizacion": "2026-10-15",
            "importe_presupuesto": 500,
            "km": 35.5,
            "horas_formacion": 2,
        },
        headers=ana,
    )
    assert r.status_code == 200, r.text
    mes = client.get("/registros", params={"anio": 2026, "mes": 10}, headers=ana).json()
    assert mes["total_km"] == 35.5 and mes["total_horas_formacion"] == 2
    assert all(reg["actividad_id"] == actividad["id"] for reg in mes["registros"])
    assert mes["registros"][0]["concepto"] == "Panadería Sol · Evaluación de riesgos"
    # 15/10/2026 es jueves: sin indicar turno, se pone "mañana"
    formacion = [reg for reg in mes["registros"] if reg["tipo"] == "formacion"][0]
    assert formacion["turno"] == "manana"
    # Si se quita el check, se quitan también esos km y horas
    client.post(f"/actividades/{actividad['id']}/deshacer", headers=ana)
    mes = client.get("/registros", params={"anio": 2026, "mes": 10}, headers=ana).json()
    assert mes["registros"] == []


def test_formacion_en_fin_de_semana_es_extra(client, usuarios, datos):  # noqa: F811
    ana = usuarios["ana"]["h"]
    actividad = client.get("/agenda/pendientes", headers=ana).json()["actividades"][0]
    # 17/10/2026 es sábado
    client.post(
        f"/actividades/{actividad['id']}/realizar",
        json={"codigo_presupuesto": "P-30", "fecha_realizacion": "2026-10-17", "importe_presupuesto": 100, "horas_formacion": 4},
        headers=ana,
    )
    mes = client.get("/registros", params={"anio": 2026, "mes": 10}, headers=ana).json()
    assert mes["horas_por_turno"]["extra_manana"] == 4
    # Indicando el turno, se respeta
    otra = client.get("/agenda/pendientes", headers=ana).json()["actividades"][0]
    client.post(
        f"/actividades/{otra['id']}/realizar",
        json={
            "codigo_presupuesto": "P-31",
            "fecha_realizacion": "2026-10-17",
            "importe_presupuesto": 100,
            "horas_formacion": 2,
            "turno_formacion": "extra_tarde",
        },
        headers=ana,
    )
    mes = client.get("/registros", params={"anio": 2026, "mes": 10}, headers=ana).json()
    assert mes["horas_por_turno"]["extra_tarde"] == 2

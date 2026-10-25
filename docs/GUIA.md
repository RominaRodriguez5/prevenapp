# PrevenApp · Guía de lo que se ha programado

Esta guía explica, fase por fase y con palabras sencillas, qué hace cada parte del backend
(la "cocina" de la aplicación). Te servirá para entender el código, para las reuniones con
el tutor y para la documentación.

> Recordatorio de la comparación: **PostgreSQL** es la despensa (guarda los datos),
> **la API en Python (FastAPI)** es la cocina (recibe peticiones y responde),
> **la app en Flutter** será el camarero (lo que ve el técnico), y **Docker** es el edificio
> que lo pone todo en marcha.

---

## Fase 1 · Base del proyecto e inicio de sesión ✅ (la hicimos juntas)

- Docker arranca la base de datos y la API.
- Tabla **usuarios** con tres roles: `tecnico`, `presupuestos` y `admin`.
- Las contraseñas se guardan **cifradas** (bcrypt), nunca tal cual.
- Al iniciar sesión, la API da un **token JWT** (la "pulsera de acceso"), que dura 8 horas.

---

## Fase 2 · Clientes y actividades del contrato

**Qué resuelve:** que el técnico tenga en un solo sitio sus clientes y lo que el contrato
de cada uno obliga a hacer cada año.

**Tablas nuevas:**

| Tabla | Para qué sirve |
|---|---|
| `clientes` | Datos del cliente y **qué técnico lo lleva** |
| `tipos_actividad` | Catálogo de actividades (Evaluación de riesgos, Formación…) con el **porcentaje** de incentivo para el captador y para el redactor (8 % por defecto) |
| `actividades_obligatorias` | El **contrato**: "este cliente necesita esta actividad cada año, desde tal año" |
| `actividades` | Cada actividad concreta de un año: pendiente, programada o realizada |

**Reglas importantes:**
- Un técnico **solo ve sus clientes**. Si intenta ver el de otro, la API responde "no encontrado"
  (así ni siquiera sabe que existe).
- Administración y presupuestos ven todo.
- Un técnico puede dar de alta sus propios clientes (la app es independiente de e-spa).
- Solo el administrador puede crear tipos de actividad y cambiar sus porcentajes.

**Decisión de diseño que puedes explicar al tutor:** separamos el *contrato*
(`actividades_obligatorias`) de las *actividades de cada año* (`actividades`). El contrato
dice "cada año hay que hacer X"; la aplicación crea automáticamente la actividad de cada año.

---

## Fase 3 · Pendientes de años anteriores (margen de 5 años)

**Qué resuelve:** el técnico no tiene que acordarse de qué le quedó sin hacer el año pasado.

- Cada vez que el técnico abre sus pendientes (`GET /agenda/pendientes`), la API **crea sola**
  las actividades del contrato que falten, sin duplicar nunca.
- Muestra las del **año actual** y las **atrasadas** de años anteriores que siguen en plazo.
- Plazo de **5 años**: el año que toca y los 4 siguientes. Con un contrato desde 2015, en 2026
  solo aparecen las de 2022 a 2026.
- Devuelve además la lista **"clientes que no has visitado el año pasado"**.
- Cada actividad lleva `atrasada: true/false` para que la app la pueda destacar en otro color.

El cálculo está en `app/services/actividades.py` → `generar_obligatorias()` y el plazo en
`app/core/fechas.py` (`MARGEN_ANIOS = 5`).

---

## Fase 4 · Calendario y guardias

**Qué resuelve:** que el técnico vea su mes de un vistazo y que nadie tenga que preguntarte
quién está de guardia.

- `PUT /guardias/{fecha}` con `{"guardia": true}` o `false`: es el "sí/no" del calendario.
- `GET /agenda`: actividades programadas y realizadas del mes, más los días de guardia.
- `GET /guardias/dia/{fecha}`: **¿quién está de guardia este día?** Lo puede consultar cualquiera.
- Al poner una fecha a una actividad, pasa de *pendiente* a **programada**.

---

## Fase 5 · El check de "actividad realizada" y el aviso a presupuestos

**Qué resuelve:** se acaba la cadena "técnico → te escribe → apuntas en el Excel".

El técnico rellena **tres datos**: el **código de presupuesto**, la **fecha** y el
**importe del presupuesto sin IVA** (`POST /actividades/{id}/realizar`). Entonces la API:

1. Marca la actividad como **realizada** (no se permiten fechas futuras ni hacer el check dos veces).
2. Si no se había indicado, pone como **redactor** a quien hace el check y como **captador**
   al técnico que lleva al cliente.
3. **Calcula y guarda el incentivo** en ese momento (ver fase 6).
4. **Envía un email a presupuestos** con: técnico, código de presupuesto, importe sin IVA, fecha, cliente y actividad.
5. Deja el aviso registrado en la tabla `avisos`, indicando si se envió o si falló.
   Si el correo falla, **la actividad sigue marcada**: el error queda anotado para revisarlo.

¿A quién llega el aviso? A todos los usuarios con rol **presupuestos**, o a los emails
que pongas en `AVISOS_DESTINATARIOS` en el `.env`.

**Deshacer:** si alguien hace el check por error, `POST /actividades/{id}/deshacer` lo quita
(idea que viene de Sprinde Board: mejor un "deshacer" que un "¿estás seguro?" cada vez).

**Para verlo en tu ordenador:** Docker arranca ahora también **Mailpit**, un buzón de pruebas.
Los correos no salen a internet: los ves en **http://localhost:8025**.

---

## Fase 6 · Captador, redactor, historial e incentivos

**Qué resuelve:** los técnicos dejan de calcular sus incentivos a mano en Excel.

- **Captador:** quien consigue la actividad. **Redactor:** quien la realiza. Pueden ser la
  misma persona (cobra las dos partes) o dos distintas (cada uno su parte).
- **El incentivo es un 8 % del importe del presupuesto sin IVA**, para el captador y otro 8 % para
  el redactor. El porcentaje se guarda en cada tipo de actividad, así que se puede cambiar si
  alguna actividad tiene un porcentaje distinto. Se redondea a céntimos: 8 % de 1.250 € = 100,00 €.
- `GET /incentivos`: incentivos del **cuatrimestre** (1: ene-abr, 2: may-ago, 3: sep-dic).
  Por defecto, el actual. Cuenta según la **fecha de realización**.
- `GET /historial`: actividades realizadas **mes a mes** durante un año.
- `GET /incentivos/resumen`: tabla con todos los técnicos (solo administración y presupuestos).
  Es tu "parte para sacar datos".

**Decisión de diseño importante:** al hacer el check se **calcula y guarda el importe** del
incentivo en la actividad. Así, si más adelante cambia el porcentaje, los incentivos ya
calculados no cambian. Es un buen ejemplo de integridad de datos para la documentación.

> **Cambio del 24/10:** al principio el incentivo era un importe fijo por tipo de actividad.
> Se cambió a un porcentaje del presupuesto con la migración `0003_incentivo_porcentaje.py`.
> Es un buen ejemplo para la documentación de cómo una migración modifica tablas que ya tienen datos.

---

## Pruebas automáticas

En `backend/tests/` hay **12 pruebas** que comprueban todo el flujo: inicio de sesión,
permisos, pendientes y margen de 5 años, guardias, el check, el email, los incentivos,
el historial y el deshacer. Se han pasado con SQLite y con PostgreSQL real.

Para ejecutarlas en tu ordenador (con el `.venv` activado, desde la carpeta `prevenapp`):

```
pip install -r backend\requirements-dev.txt
cd backend
pytest
```

Debe salir `12 passed`. Esto encaja con el apartado de **plan de pruebas** del guion.

---

## Cómo probarlo todo tú

1. Para Docker si estaba en marcha (**Ctrl + C**) y arráncalo de nuevo:
   ```
   docker compose up --build
   ```
   Las tablas nuevas se crean solas al arrancar (migraciones `0002` y `0003`).
2. En otra terminal, carga datos de ejemplo:
   ```
   docker compose exec api python -m app.datos_demo
   ```
   Crea `ana@previs.es`, `luis@previs.es` (técnicos) y `presupuestos@previs.es`, todos con la
   contraseña `demo1234`, además de clientes, contratos y guardias.
3. Abre **http://localhost:8000/docs**, pulsa **Authorize** y entra como `ana@previs.es`.
4. Prueba en este orden:
   - `GET /agenda/pendientes` → verás sus actividades, incluidas las atrasadas.
   - Copia el `id` de una y prueba `POST /actividades/{id}/realizar` con:
     ```json
     {"codigo_presupuesto": "P-2026-0001", "fecha_realizacion": "2026-10-23", "importe_presupuesto": 1250}
     ```
   - Abre **http://localhost:8025** → ¡ahí está el email para presupuestos!
   - `GET /incentivos` → verás lo que ha ganado Ana este cuatrimestre.

---

## Lista de rutas de la API

| Método | Ruta | Quién | Qué hace |
|---|---|---|---|
| POST | `/auth/login` | todos | Iniciar sesión |
| GET | `/auth/yo` | todos | Mis datos |
| GET/POST | `/usuarios` | admin | Listar / crear usuarios |
| GET | `/tipos-actividad` | todos | Catálogo de actividades |
| POST/PATCH | `/tipos-actividad` | admin | Crear / cambiar tipos y porcentajes |
| GET/POST | `/clientes` | todos* | Mis clientes / nuevo cliente |
| GET/PATCH | `/clientes/{id}` | todos* | Ver / editar cliente |
| GET/POST | `/clientes/{id}/obligatorias` | todos* | Contrato del cliente |
| DELETE | `/clientes/{id}/obligatorias/{id}` | todos* | Quitar del contrato |
| GET/POST | `/actividades` | todos* | Listar / crear actividad extra |
| PATCH | `/actividades/{id}` | todos* | Programar fecha, captador, redactor, notas |
| POST | `/actividades/{id}/realizar` | todos* | **El check** |
| POST | `/actividades/{id}/deshacer` | todos* | Quitar el check |
| GET | `/agenda/pendientes` | todos* | Pendientes y atrasadas |
| GET | `/agenda` | todos* | Calendario del mes |
| PUT | `/guardias/{fecha}` | todos* | Guardia sí / no |
| GET | `/guardias/dia/{fecha}` | todos | Quién está de guardia |
| GET | `/historial` | todos* | Historial mensual |
| GET | `/incentivos` | todos* | Incentivos del cuatrimestre |
| GET | `/incentivos/resumen` | admin, presupuestos | Incentivos de todos |
| GET | `/avisos` | admin, presupuestos | Avisos enviados |

\* Un técnico solo ve y modifica lo suyo.

---

## Cosas que tienes que confirmar tú

He tomado estas decisiones para poder avanzar. Si alguna no es como funciona en tu empresa,
se cambia fácilmente:

1. **Margen de 5 años:** lo he interpretado como "el año que toca y los 4 siguientes".
2. **Cuatrimestres fijos:** enero-abril, mayo-agosto y septiembre-diciembre.
3. **Captador por defecto:** si no se indica, es el técnico que lleva al cliente.
4. **El incentivo cuenta cuando la actividad está realizada**, no cuando se factura o se cobra.
5. **Incentivo = 8 % del presupuesto sin IVA para cada uno** (captador y redactor). Pendiente de
   ajustar con la documentación de la empresa (¿8 % cada uno o 8 % a repartir?).
6. **Los técnicos dan de alta sus propios clientes.** Si prefieres que lo haga solo administración,
   es un cambio de una línea.

---

## Siguiente paso: la app móvil en Flutter

El backend ya está completo. Lo siguiente es la app de los técnicos, que haremos juntas por fases:

1. Instalar Flutter en tu ordenador y crear el proyecto.
2. Pantalla de inicio de sesión.
3. Pantalla de pendientes (con las atrasadas destacadas).
4. Ficha del cliente y de la actividad con el botón del check.
5. Calendario con guardias.
6. Pantalla de incentivos e historial.

---

## La app móvil (Flutter)

### Identidad visual: la "libreta de campo"

La app no copia el estilo de ninguna otra: está pensada para técnicos de prevención.

| Elemento | Significado |
|---|---|
| Fondo **color papel** y textos **azul tinta** | Una libreta de campo de verdad |
| **Naranja alta visibilidad** | El de los chalecos de seguridad: botones y visitas programadas |
| **Cinta de balizamiento** (rayas amarillas y negras) | Actividades **atrasadas**: se entiende sin leer |
| **Sello verde "REALIZADA"** | Aparece estampado (con animación) al hacer el check |
| **Ticket** con borde dentado | Los incentivos del cuatrimestre, como un recibo |

Los colores están todos en `lib/tema.dart` (clase `Paleta`), así que cambiarlos es fácil.

### Pantallas

| Archivo | Pantalla |
|---|---|
| `pantallas/login.dart` | Inicio de sesión: solo el usuario (se añade `@previs.es`) y la contraseña |
| `pantallas/inicio.dart` | Saludo, fecha y las 3 pestañas de abajo |
| `pantallas/pendientes.dart` | Cuántas actividades quedan, cuáles están atrasadas y clientes sin visitar |
| `pantallas/actividad.dart` | Ficha: programar visita, **check** (código, importe y fecha) y deshacer |
| `pantallas/calendario.dart` | Mes con visitas, realizadas y guardias; interruptor "Estoy de guardia" y quién más está de guardia |
| `pantallas/incentivos.dart` | Ticket de incentivos del cuatrimestre y gráfico de actividades por mes |

### Organización del código

| Carpeta | Para qué |
|---|---|
| `servicios/api.dart` | Habla con la API (el "camarero") |
| `modelos/` | Clases que representan los datos (Actividad, Pendientes) |
| `widgets/` | Piezas reutilizables: la cinta de baliza y el sello |
| `utilidades/formato.dart` | Fechas (05/10/2026) e importes (1250,50 €) en formato español |
| `config.dart` | Dirección de la API y dominio de la empresa |
| `tema.dart` | Colores y estilos |

### Probar la app

```
cd movil
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

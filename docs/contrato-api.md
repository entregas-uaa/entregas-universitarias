# Contrato de la API REST

Acuerdo entre el backend y la app sobre las operaciones, los datos y los errores. Si algo cambia, se actualiza aquí con un Pull Request.

**Convenciones.**
- JSON en ambos sentidos, salvo la subida de fotos (`multipart/form-data`).
- Autenticación: `Authorization: Bearer <token>` en todo lo que no sea público.
- Sin prefijo en las rutas (`/entregas`, no `/api/v1/entregas`).

## Errores comunes

| Código | Cuándo |
| --- | --- |
| **401** | No hay token, es inválido o expiró |
| **403** | Hay sesión, pero el rol o la propiedad del recurso no permiten la acción |
| **404** | El recurso no existe (o no es visible para ese usuario) |
| **409** | La acción no es válida para el estado actual (transición incorrecta, entrega ya cancelada…) |
| **413** | La imagen pesa más de 2 MB |
| **422** | Datos inválidos: campo faltante, formato incorrecto, receptor vacío… |

El cuerpo es `{"detail": "mensaje en español"}`. En los 422 por validación de campos, FastAPI devuelve en `detail` una lista de objetos con el campo y el motivo.

## Endpoints

Rol: **P** = público · **U** = usuario general · **O** = operador · **D** = dueño de la entrega (su solicitante) · **OA** = operador asignado a esa entrega.

| Método y ruta | Quién | Recibe | Responde | Errores |
| --- | --- | --- | --- | --- |
| `GET /health` | P | — | `200 {"status":"ok"}` | — |
| `POST /auth/registro` | P | `nombre`, `correo`, `password` (≥ 8) | `201` usuario | 409 correo repetido, 422 |
| `POST /auth/login` | P | `correo`, `password` | `200 {access_token, token_type, usuario}` | 401, 422 |
| `GET /auth/me` | U, O | — | `200` usuario | 401 |
| `PATCH /auth/me` | U, O | `nombre?`, `password?` | `200` usuario | 401, 422 |
| `GET /categorias` | U, O | — | `200` lista de categorías | 401 |
| `POST /entregas` | U | `categoria_id`, `descripcion`, `es_fragil`, `origen_descripcion`, `origen_lat?`, `origen_lng?`, `destino_descripcion` | `201` entrega (estado `pendiente`) | 401, 403, 422 |
| `GET /entregas` | U (las suyas), O (todas) | Parámetros opcionales: `estado`, `categoria_id`, `q` (texto en descripción, origen y destino), `mias=true` (operador: solo las asignadas a él) | `200` lista de resúmenes | 401 |
| `GET /entregas/{id}` | D, O | — | `200` detalle con evidencias e historial | 401, 403, 404 |
| `PATCH /entregas/{id}` | D, solo si `pendiente` y no cancelada | Cualquier campo editable de `POST /entregas` | `200` entrega | 403, 404, 409, 422 |
| `POST /entregas/{id}/cancelar` | D, solo si `pendiente` | — | `200` entrega (con `cancelada: true`) | 403, 404, 409 |
| `POST /entregas/{id}/aceptar` | O | — | `200` entrega (`aceptada`, con operador) | 403, 404, 409 |
| `POST /entregas/{id}/recoleccion` | OA | `nota?` | `200` entrega (`en_traslado`) | 403, 404, 409 |
| `POST /entregas/{id}/entrega` | OA | `receptor_nombre` (**obligatorio, no vacío**) | `200` entrega (`entregada`) | 403, 404, 409, **422** si el receptor falta |
| `POST /entregas/{id}/impactos` | OA, solo si `es_fragil` y `en_traslado` | `intensidad` (número) | `201` evento de historial | 403, 404, 409, 422 |
| `POST /entregas/{id}/evidencias` | D, OA | Campo `archivo` (JPEG o PNG, ≤ 2 MB) | `201 {id, tipo_mime, creada_en}` | 403, 404, 413, 422 |
| `GET /evidencias/{id}` | D, O | — | `200` bytes de la imagen con su `Content-Type` | 401, 403, 404 |

El historial viaja dentro del detalle de la entrega; no hay endpoint aparte.

## Quién puede qué

| Acción | Usuario general | Operador |
| --- | --- | --- |
| Registrarse e iniciar sesión | Sí | Sí (cuenta creada por script) |
| Crear entregas | **Sí** | No |
| Ver entregas | Solo las suyas | Todas |
| Editar y cancelar | Solo las suyas y solo pendientes | No |
| Aceptar | No | **Sí** |
| Recolección, entrega e impactos | No | Solo en las que tiene asignadas |
| Subir evidencias | En sus entregas | En las asignadas |

## Transiciones de estado

```
pendiente ──aceptar──▶ aceptada ──recoleccion──▶ en_traslado ──entrega──▶ entregada
   │
   └──cancelar──▶ (sigue en pendiente, con cancelada_en lleno)
```

Cualquier otro salto responde **409** y no cambia nada. Cada transición válida escribe su renglón de historial en la misma transacción.

## Ejemplos de objetos

**Usuario**
```json
{"id": 1, "nombre": "Ana Pérez", "correo": "ana@correo.com", "rol": "usuario"}
```

**Resumen de entrega** (en `GET /entregas`)
```json
{
  "id": 12,
  "descripcion": "Tesis impresa para entregar a posgrado",
  "estado": "en_traslado",
  "es_fragil": false,
  "cancelada": false,
  "categoria": {"id": 1, "nombre": "Documento"},
  "origen_descripcion": "Biblioteca, planta baja",
  "destino_descripcion": "Edificio 3, oficina de posgrado",
  "solicitante": {"id": 1, "nombre": "Ana Pérez"},
  "operador": {"id": 7, "nombre": "Luis Mora"},
  "creada_en": "2026-11-20T15:32:10Z",
  "actualizada_en": "2026-11-20T16:05:44Z"
}
```

**Detalle** (`GET /entregas/{id}`): lo anterior más:
```json
{
  "origen_lat": 21.9157,
  "origen_lng": -102.3187,
  "receptor_nombre": null,
  "evidencias": [{"id": 5, "tipo_mime": "image/jpeg", "creada_en": "2026-11-20T15:33:02Z"}],
  "historial": [
    {"id": 31, "tipo_evento": "creacion", "estado_anterior": null, "estado_nuevo": "pendiente",
     "usuario": {"id": 1, "nombre": "Ana Pérez"}, "intensidad": null, "detalle": null,
     "creado_en": "2026-11-20T15:32:10Z"},
    {"id": 33, "tipo_evento": "impacto", "estado_anterior": null, "estado_nuevo": null,
     "usuario": {"id": 7, "nombre": "Luis Mora"}, "intensidad": 18.4, "detalle": null,
     "creado_en": "2026-11-20T16:01:12Z"}
  ]
}
```

**Error**
```json
{"detail": "La entrega ya no está pendiente y no se puede cancelar"}
```

## Estructura del repositorio y dueños de carpeta

Cada carpeta tiene un dueño para que los tres trabajen en paralelo sin chocar. Si alguien necesita cambiar una carpeta ajena, avisa al dueño o lo hace por PR con su revisión.

```
entregas-universitarias/
├─ app/                    Flutter (lo crea Rodrigo en su primer Issue)
│  └─ lib/
│     ├─ ui/               Rodrigo · pantallas, widgets y tema
│     ├─ state/            Santiago · estado (Provider)
│     ├─ routing/          Santiago · rutas (go_router)
│     ├─ services/         Santiago · cámara, ubicación, sensor, almacenamiento local
│     ├─ data/             Ramiro · modelos y cliente HTTP
│     └─ main.dart         Santiago
├─ backend/                Ramiro · API FastAPI
├─ db/                     Ramiro · scripts SQL (crear tablas y datos semilla)
├─ docs/                   ER, contrato de la API y notas
└─ .github/                plantillas de Issue y de Pull Request
```

**La capa `data/` (propuesta).** Ramiro la implementa y Santiago la consume desde `state/`. Mientras no exista, Santiago trabaja contra una versión falsa de estas interfaces:

- `AuthRepository`: `login`, `registro`, `me`.
- `CategoriasRepository`: `listar`.
- `EntregasRepository`: `listar` (con filtros), `obtener`, `crear`, `editar`, `cancelar`, `aceptar`, `registrarRecoleccion`, `entregar`, `reportarImpacto`, `subirEvidencia`, `descargarEvidencia`.

**Regla de capas.** `ui/` no llama al backend ni a la base local: recibe datos y funciones desde `state/`. `state/` habla con `data/` y `services/`. Así cada integrante puede explicar su capa en la defensa y un cambio en una no rompe las otras.

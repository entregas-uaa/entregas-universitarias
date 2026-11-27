-- Esquema de la base de datos central: sistema de entregas universitarias (PostgreSQL).
-- Se ejecuta una sola vez sobre una base vacía. Todo va en una transacción:
-- si algo falla, no se crea nada.
BEGIN;

CREATE TABLE usuarios (
    id            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(120) NOT NULL CHECK (length(trim(nombre)) > 0),
    correo        VARCHAR(254) NOT NULL UNIQUE CHECK (correo = lower(correo)),
    password_hash TEXT NOT NULL,
    rol           VARCHAR(10) NOT NULL DEFAULT 'usuario'
                  CHECK (rol IN ('usuario', 'operador')),
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE categorias (
    id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE entregas (
    id                  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    solicitante_id      INTEGER NOT NULL REFERENCES usuarios (id) ON DELETE RESTRICT,
    operador_id         INTEGER REFERENCES usuarios (id) ON DELETE RESTRICT,
    categoria_id        INTEGER NOT NULL REFERENCES categorias (id) ON DELETE RESTRICT,
    descripcion         TEXT NOT NULL CHECK (length(trim(descripcion)) > 0),
    es_fragil           BOOLEAN NOT NULL DEFAULT FALSE,
    origen_descripcion  VARCHAR(200) NOT NULL CHECK (length(trim(origen_descripcion)) > 0),
    origen_lat          DOUBLE PRECISION CHECK (origen_lat BETWEEN -90 AND 90),
    origen_lng          DOUBLE PRECISION CHECK (origen_lng BETWEEN -180 AND 180),
    destino_descripcion VARCHAR(200) NOT NULL CHECK (length(trim(destino_descripcion)) > 0),
    estado              VARCHAR(12) NOT NULL DEFAULT 'pendiente'
                        CHECK (estado IN ('pendiente', 'aceptada', 'en_traslado', 'entregada')),
    receptor_nombre     VARCHAR(120),
    cancelada_en        TIMESTAMPTZ,
    creada_en           TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizada_en      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Las coordenadas van juntas: las dos o ninguna.
    CONSTRAINT coordenadas_completas
        CHECK ((origen_lat IS NULL) = (origen_lng IS NULL)),
    -- Regla específica del sistema: no hay entrega sin el nombre de quien recibió.
    CONSTRAINT receptor_obligatorio_al_entregar
        CHECK (estado <> 'entregada' OR length(trim(coalesce(receptor_nombre, ''))) > 0),
    -- Solo una entrega pendiente puede estar sin operador.
    CONSTRAINT operador_obligatorio
        CHECK (estado = 'pendiente' OR operador_id IS NOT NULL),
    -- Solo se puede cancelar lo que sigue pendiente.
    CONSTRAINT solo_se_cancela_pendiente
        CHECK (cancelada_en IS NULL OR estado = 'pendiente')
);

CREATE TABLE evidencias (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entrega_id INTEGER NOT NULL REFERENCES entregas (id) ON DELETE CASCADE,
    subida_por INTEGER NOT NULL REFERENCES usuarios (id) ON DELETE RESTRICT,
    imagen     BYTEA NOT NULL CHECK (octet_length(imagen) <= 2 * 1024 * 1024),
    tipo_mime  VARCHAR(20) NOT NULL CHECK (tipo_mime IN ('image/jpeg', 'image/png')),
    creada_en  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE historial (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entrega_id      INTEGER NOT NULL REFERENCES entregas (id) ON DELETE CASCADE,
    usuario_id      INTEGER NOT NULL REFERENCES usuarios (id) ON DELETE RESTRICT,
    tipo_evento     VARCHAR(15) NOT NULL
                    CHECK (tipo_evento IN ('creacion', 'edicion', 'cambio_estado', 'impacto', 'cancelacion')),
    estado_anterior VARCHAR(12)
                    CHECK (estado_anterior IN ('pendiente', 'aceptada', 'en_traslado', 'entregada')),
    estado_nuevo    VARCHAR(12)
                    CHECK (estado_nuevo IN ('pendiente', 'aceptada', 'en_traslado', 'entregada')),
    intensidad      DOUBLE PRECISION CHECK (intensidad > 0),
    detalle         TEXT,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices para las búsquedas que la API hará todo el tiempo.
CREATE INDEX idx_entregas_solicitante ON entregas (solicitante_id);
CREATE INDEX idx_entregas_estado ON entregas (estado);
CREATE INDEX idx_evidencias_entrega ON evidencias (entrega_id);
CREATE INDEX idx_historial_entrega ON historial (entrega_id);

COMMIT;

-- Datos iniciales. Se puede ejecutar varias veces sin duplicar nada.
-- Aquí no hay usuarios a propósito: el repositorio es público y no lleva contraseñas.
INSERT INTO categorias (nombre)
VALUES ('Documento'), ('Material'), ('Paquete')
ON CONFLICT (nombre) DO NOTHING;

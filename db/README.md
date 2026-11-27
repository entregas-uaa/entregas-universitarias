# Base de datos

PostgreSQL 17, alojado en Neon.
Base de datos: `entregas`, en la rama `production`.

## Crear la base

En el editor SQL de Neon, ejecuta en este orden:

1. `schema.sql`: crea las tablas, sus reglas y los índices. Solo sobre una base vacía.
2. `seed.sql`: carga las categorías. Se puede repetir.

## Crear un operador

El registro de la API siempre crea usuarios con rol `usuario`. Para convertir una cuenta en operador,
primero se registra desde la API y luego se ejecuta en el editor SQL, con su correo:

```sql
UPDATE usuarios SET rol = 'operador' WHERE correo = 'correo-de-la-cuenta';
```

## Secretos

La cadena de conexión no se escribe en el repositorio: va en `backend/.env` en local
y en las variables de entorno del host.

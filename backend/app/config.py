"""Configuración de la API, leída de variables de entorno."""
import os

from dotenv import load_dotenv

#Para cargar las variables de entorno del host o de mi computadora
load_dotenv()


class Settings:
    def __init__(self):
        # Orígenes web que pueden llamar a la API, separados por comas. "*" = cualquiera.
        origins = os.getenv("CORS_ORIGINS", "*")
        self.cors_origins = [o.strip() for o in origins.split(",") if o.strip()]


settings = Settings()
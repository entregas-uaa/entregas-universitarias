"""Punto de entrada de la API de entregas universitarias."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings

app = FastAPI(title="API de entregas universitarias", version="0.1.0")

# Sin esto, el navegador bloquea las peticiones de la versión web de la app.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", tags=["salud"])
def health():
    """Dice si el servidor está vivo. También sirve para despertar el host."""
    return {"status": "ok"}
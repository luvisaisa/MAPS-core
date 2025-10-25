"""FastAPI application factory"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware


def create_app() -> FastAPI:
    """Create and configure FastAPI application"""
    app = FastAPI(
        title="MAPS API",
        description="Medical Annotation Processing System REST API",
        version="1.0.0",
        docs_url="/docs",
        redoc_url="/redoc"
    )

    # CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Configure for production
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Register routers
    from .routers import health, parser, profiles, keywords, analysis

    app.include_router(health.router, prefix="/api", tags=["health"])
    app.include_router(parser.router, prefix="/api/parse", tags=["parser"])
    app.include_router(profiles.router, prefix="/api/profiles", tags=["profiles"])
    app.include_router(keywords.router, prefix="/api/keywords", tags=["keywords"])
    app.include_router(analysis.router, prefix="/api/analysis", tags=["analysis"])

    return app

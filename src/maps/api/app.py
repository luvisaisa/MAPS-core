"""FastAPI application factory"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError


def create_app() -> FastAPI:
    """Create and configure FastAPI application"""
    app = FastAPI(
        title="MAPS API",
        description="Medical Annotation Processing System REST API",
        version="1.0.0",
        docs_url="/docs",
        redoc_url="/redoc"
    )

    # Add middleware
    from .middleware import LoggingMiddleware, validation_exception_handler, general_exception_handler

    app.add_middleware(LoggingMiddleware)

    # CORS middleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Configure for production
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Exception handlers
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(Exception, general_exception_handler)

    # Register routers
    from .routers import health, parser, profiles, keywords, analysis, detection

    app.include_router(health.router, prefix="/api", tags=["health"])
    app.include_router(parser.router, prefix="/api/parse", tags=["parser"])
    app.include_router(profiles.router, prefix="/api/profiles", tags=["profiles"])
    app.include_router(keywords.router, prefix="/api/keywords", tags=["keywords"])
    app.include_router(analysis.router, prefix="/api/analysis", tags=["analysis"])
    app.include_router(detection.router, prefix="/api/detect", tags=["detection"])

    return app

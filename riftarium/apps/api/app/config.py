from pydantic_settings import BaseSettings

WEAK_JWT_SECRETS = frozenset(
    {
        "",
        "dev-secret-change-me",
        "test-secret",
        "test-secret-not-for-production-use!",
        "change-me",
        "secret",
        "changeme",
    }
)


class Settings(BaseSettings):
    riftarium_env: str = "dev"  # dev | test | prod
    database_url: str = "sqlite:///./riftarium.db"
    jwt_secret: str = "dev-secret-change-me"
    jwt_ttl_hours: int = 24
    admin_token: str = ""
    cookie_secure: bool = False
    auth_rate_limit: int = 20  # tentatives / minute / IP (login + inscription)
    auto_sync: bool = True
    riftcodex_base_url: str = "https://api.riftcodex.com"
    sync_sets: str = "OGN,OGS,SFD,UNL,VEN,PR"
    redis_url: str = ""  # vide = cache désactivé (tests, dev sans Redis)
    cache_ttl_seconds: int = 6 * 3600
    sync_min_interval_minutes: int = 10  # protège l'API Riftcodex des resync en rafale
    riftcodex_page_delay: float = 0.3  # pause entre deux pages lors d'une sync
    image_hosts: str = ""  # hôtes HTTPS supplémentaires, séparés par des virgules

    @property
    def is_prod(self) -> bool:
        return self.riftarium_env == "prod"

    @property
    def expose_docs(self) -> bool:
        return self.riftarium_env != "prod"


settings = Settings()


def validate_production_settings() -> None:
    """Refuse de démarrer en production avec des secrets trop faibles ou absents."""
    if not settings.is_prod:
        return
    if settings.jwt_secret in WEAK_JWT_SECRETS or len(settings.jwt_secret) < 24:
        raise RuntimeError("JWT_SECRET doit être défini (24 caractères min.) et ne pas être une valeur d'exemple.")
    if len(settings.admin_token) < 16:
        raise RuntimeError("ADMIN_TOKEN (16 caractères min.) est requis pour la synchronisation admin.")

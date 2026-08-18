from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite:///./riftarium.db"
    jwt_secret: str = "dev-secret-change-me"
    jwt_ttl_hours: int = 72
    auto_sync: bool = True
    riftcodex_base_url: str = "https://api.riftcodex.com"
    sync_sets: str = "OGN,OGS,SFD,UNL,VEN,PR"
    redis_url: str = ""  # vide = cache désactivé (tests, dev sans Redis)
    cache_ttl_seconds: int = 6 * 3600
    sync_min_interval_minutes: int = 10  # protège l'API Riftcodex des resync en rafale
    riftcodex_page_delay: float = 0.3  # pause entre deux pages lors d'une sync


settings = Settings()

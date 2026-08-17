from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite:///./riftarium.db"
    jwt_secret: str = "dev-secret-change-me"
    jwt_ttl_hours: int = 72
    auto_sync: bool = True
    riftcodex_base_url: str = "https://api.riftcodex.com"
    sync_sets: str = "OGN,OGS,SFD,UNL,VEN,PR"


settings = Settings()

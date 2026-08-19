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
    auth_account_rate_limit: int = 10  # tentatives / heure / compte (login)
    # Paramètres scrypt (mots de passe). Abaissés dans les tests pour rester rapides.
    scrypt_n: int = 2**17
    scrypt_r: int = 8
    scrypt_p: int = 1
    auto_sync: bool = True
    riftcodex_base_url: str = "https://api.riftcodex.com"
    sync_sets: str = "OGN,OGS,SFD,UNL,VEN,PR"
    redis_url: str = ""  # vide = cache désactivé (tests, dev sans Redis)
    cache_ttl_seconds: int = 6 * 3600
    sync_min_interval_minutes: int = 10  # protège l'API Riftcodex des resync en rafale
    riftcodex_page_delay: float = 0.3  # pause entre deux pages lors d'une sync
    image_hosts: str = ""  # hôtes HTTPS supplémentaires, séparés par des virgules
    # E-mails transactionnels (vérification d'adresse, réinitialisation de mot de passe).
    # SMTP_HOST vide = mode console : les messages sont loggés au lieu d'être envoyés (dev).
    smtp_host: str = ""
    smtp_port: int = 465  # 465 = SSL implicite, sinon STARTTLS (587 chez OVH)
    smtp_user: str = ""
    smtp_password: str = ""
    mail_from: str = "Riftarium <contact@riftarium.re>"
    public_base_url: str = ""  # vide = déduit de l'environnement (voir base_url)
    email_rate_limit: int = 3  # e-mails / heure / adresse (reset + renvoi de vérification)

    @property
    def is_prod(self) -> bool:
        return self.riftarium_env == "prod"

    @property
    def base_url(self) -> str:
        """Base des liens envoyés par e-mail (sans « / » final)."""
        if self.public_base_url:
            return self.public_base_url.rstrip("/")
        return "https://riftarium.re" if self.is_prod else "http://localhost:8888"

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

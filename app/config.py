from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "list_master"
    debug: bool = False

    database_url: str = "postgresql+asyncpg://localhost:5432/list_master"

    host: str = "0.0.0.0"
    port: int = 8000


settings = Settings()

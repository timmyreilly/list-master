from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "list_master"
    debug: bool = False

    database_url: str = "postgresql+asyncpg://listmaster:listmaster@db:5432/listmaster"

    host: str = "0.0.0.0"
    port: int = 8000

    whatsapp_verify_token: str = ""
    whatsapp_api_token: str = ""
    openai_api_key: str = ""


settings = Settings()

import os
import hmac
import logging
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException
from google import genai
from google.genai.types import GenerateContentConfig, HttpOptions
from pydantic import BaseModel, Field


PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT")
LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION", "global")
MODEL_ID = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")
MODEL_IDS = [
    model.strip()
    for model in os.getenv("GEMINI_MODELS", MODEL_ID).split(",")
    if model.strip()
]
INTERNAL_API_KEY = os.getenv("INTERNAL_API_KEY")

logger = logging.getLogger(__name__)

app = FastAPI(title="Gemini Cloud Run POC", version="0.1.0")


class GenerateRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=8000)
    model: str | None = None
    temperature: float = Field(default=0.2, ge=0.0, le=2.0)
    max_output_tokens: int = Field(default=512, ge=1, le=8192)


class GenerateResponse(BaseModel):
    model: str
    location: str
    text: str


def require_internal_api_key(
    x_internal_api_key: str | None = Header(default=None, alias="X-Internal-Api-Key"),
) -> None:
    if not INTERNAL_API_KEY:
        return

    if not x_internal_api_key or not hmac.compare_digest(
        x_internal_api_key,
        INTERNAL_API_KEY,
    ):
        raise HTTPException(status_code=401, detail="Unauthorized.")


def _client() -> genai.Client:
    if not PROJECT_ID:
        raise HTTPException(
            status_code=500,
            detail="GOOGLE_CLOUD_PROJECT is not configured.",
        )

    return genai.Client(
        vertexai=True,
        project=PROJECT_ID,
        location=LOCATION,
        http_options=HttpOptions(api_version="v1"),
    )


def _selected_model(requested_model: str | None) -> str:
    model = requested_model or MODEL_ID

    if model not in MODEL_IDS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported model. Allowed models: {', '.join(MODEL_IDS)}",
        )

    return model


@app.get("/healthz")
def healthz() -> dict[str, Any]:
    return {
        "status": "ok",
        "model": MODEL_ID,
        "models": MODEL_IDS,
        "location": LOCATION,
    }


@app.get("/status", dependencies=[Depends(require_internal_api_key)])
def status() -> dict[str, Any]:
    return healthz()


@app.post(
    "/generate",
    response_model=GenerateResponse,
    dependencies=[Depends(require_internal_api_key)],
)
def generate(request: GenerateRequest) -> GenerateResponse:
    model = _selected_model(request.model)

    try:
        response: Any = _client().models.generate_content(
            model=model,
            contents=request.prompt,
            config=GenerateContentConfig(
                temperature=request.temperature,
                max_output_tokens=request.max_output_tokens,
            ),
        )
    except Exception as exc:
        exception_type = type(exc).__name__
        exception_message = str(exc)
        logger.error(
            "vertex_generate_content_failed model=%s location=%s exception_type=%s exception_message=%s",
            model,
            LOCATION,
            exception_type,
            exception_message,
        )
        raise HTTPException(
            status_code=502,
            detail={
                "error": "vertex_generate_content_failed",
                "message": (
                    "The backend reached Cloud Run but failed while calling "
                    "Vertex AI Gemini."
                ),
                "exception_type": exception_type,
                "exception_message": exception_message,
            },
        ) from exc

    return GenerateResponse(
        model=model,
        location=LOCATION,
        text=response.text or "",
    )

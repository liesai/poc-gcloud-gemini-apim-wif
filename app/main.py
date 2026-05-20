import os
import hmac
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException
from google import genai
from google.genai.types import GenerateContentConfig, HttpOptions
from pydantic import BaseModel, Field


PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT")
LOCATION = os.getenv("GOOGLE_CLOUD_LOCATION", "global")
MODEL_ID = os.getenv("GEMINI_MODEL", "gemini-2.5-flash-lite")
INTERNAL_API_KEY = os.getenv("INTERNAL_API_KEY")

app = FastAPI(title="Gemini Cloud Run POC", version="0.1.0")


class GenerateRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=8000)
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


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok", "model": MODEL_ID, "location": LOCATION}


@app.get("/status", dependencies=[Depends(require_internal_api_key)])
def status() -> dict[str, str]:
    return healthz()


@app.post(
    "/generate",
    response_model=GenerateResponse,
    dependencies=[Depends(require_internal_api_key)],
)
def generate(request: GenerateRequest) -> GenerateResponse:
    try:
        response: Any = _client().models.generate_content(
            model=MODEL_ID,
            contents=request.prompt,
            config=GenerateContentConfig(
                temperature=request.temperature,
                max_output_tokens=request.max_output_tokens,
            ),
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc

    return GenerateResponse(
        model=MODEL_ID,
        location=LOCATION,
        text=response.text or "",
    )

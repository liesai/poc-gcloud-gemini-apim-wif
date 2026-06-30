import os
import hmac
import logging
from typing import Any

from fastapi import Depends, FastAPI, Header, HTTPException
from google import genai
from google.genai.types import GenerateContentConfig, HttpOptions
from pydantic import BaseModel, ConfigDict, Field, model_validator


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
    model_config = ConfigDict(extra="allow")

    prompt: str | None = Field(default=None, min_length=1, max_length=8000)
    contents: Any = None
    model: str | None = None
    config: dict[str, Any] | None = None
    system_instruction: Any = None
    tools: list[Any] | None = None
    tool_config: dict[str, Any] | None = None
    safety_settings: list[Any] | None = None
    raw_response: bool = False
    temperature: float | None = Field(default=None, ge=0.0, le=2.0)
    max_output_tokens: int | None = Field(default=None, ge=1, le=65536)

    @model_validator(mode="after")
    def require_prompt_or_contents(self) -> "GenerateRequest":
        if self.prompt is None and self.contents is None:
            raise ValueError("Either prompt or contents is required.")
        return self


class GenerateResponse(BaseModel):
    model_config = ConfigDict(extra="allow")

    model: str
    location: str
    text: str
    candidates: Any = None
    finish_reason: Any = None
    safety_ratings: Any = None
    usage_metadata: Any = None
    prompt_feedback: Any = None
    raw_response: Any = None


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
    return requested_model or MODEL_ID


def _to_jsonable(value: Any) -> Any:
    if value is None or isinstance(value, str | int | float | bool):
        return value

    if isinstance(value, list | tuple | set):
        return [_to_jsonable(item) for item in value]

    if isinstance(value, dict):
        return {str(key): _to_jsonable(item) for key, item in value.items()}

    if hasattr(value, "model_dump"):
        try:
            return _to_jsonable(value.model_dump(mode="json", exclude_none=True))
        except Exception:
            pass

    if hasattr(value, "to_json_dict"):
        try:
            return _to_jsonable(value.to_json_dict())
        except Exception:
            pass

    if hasattr(value, "__dict__"):
        return _to_jsonable(
            {
                key: item
                for key, item in vars(value).items()
                if not key.startswith("_")
            }
        )

    return str(value)


def _response_attr(response: Any, name: str) -> Any:
    return _to_jsonable(getattr(response, name, None))


def _first_candidate_attr(response: Any, name: str) -> Any:
    candidates = getattr(response, "candidates", None) or []
    if not candidates:
        return None
    return _to_jsonable(getattr(candidates[0], name, None))


def _response_text(response: Any) -> str:
    try:
        return response.text or ""
    except Exception as exc:
        logger.warning(
            "vertex_generate_content_text_unavailable exception_type=%s exception_message=%s",
            type(exc).__name__,
            str(exc),
        )
        return ""


def _build_config(request: GenerateRequest) -> GenerateContentConfig | None:
    config_payload = dict(request.config or {})

    if request.temperature is not None:
        config_payload.setdefault("temperature", request.temperature)

    if request.max_output_tokens is not None:
        config_payload.setdefault("max_output_tokens", request.max_output_tokens)

    for request_field, config_field in (
        ("system_instruction", "system_instruction"),
        ("tools", "tools"),
        ("tool_config", "tool_config"),
        ("safety_settings", "safety_settings"),
    ):
        value = getattr(request, request_field)
        if value is not None:
            config_payload.setdefault(config_field, value)

    if request.model_extra:
        for key, value in request.model_extra.items():
            config_payload.setdefault(key, value)

    if not config_payload:
        return None

    try:
        return GenerateContentConfig(**config_payload)
    except Exception as exc:
        raise HTTPException(
            status_code=400,
            detail={
                "error": "invalid_generate_content_config",
                "message": "The provided Gemini generation config is invalid.",
                "exception_type": type(exc).__name__,
                "exception_message": str(exc),
            },
        ) from exc


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
    contents = request.contents if request.contents is not None else request.prompt
    config = _build_config(request)

    try:
        client = _client()
        response: Any = client.models.generate_content(
            model=model,
            contents=contents,
            config=config,
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
        text=_response_text(response),
        candidates=_response_attr(response, "candidates"),
        finish_reason=_first_candidate_attr(response, "finish_reason"),
        safety_ratings=_first_candidate_attr(response, "safety_ratings"),
        usage_metadata=_response_attr(response, "usage_metadata"),
        prompt_feedback=_response_attr(response, "prompt_feedback"),
        raw_response=_to_jsonable(response) if request.raw_response else None,
    )

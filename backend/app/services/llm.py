from groq import Groq
from app.config import get_settings

# Models known to support the reasoning_effort parameter on Groq.
# Silently ignored for all other models to avoid bad request errors.
THINKING_MODELS: set[str] = {
    "qwen/qwen3-32b",
}

_client: Groq | None = None


def get_client() -> Groq:
    global _client
    if _client is None:
        settings = get_settings()
        _client = Groq(api_key=settings.groq_api_key)
    return _client


def _build_messages(system_prompt: str, history: list[dict], user_message: str) -> list[dict]:
    messages = [{"role": "system", "content": system_prompt}]
    messages.extend(history)
    messages.append({"role": "user", "content": user_message})
    return messages


def _base_kwargs(messages: list[dict]) -> dict:
    settings = get_settings()
    kwargs: dict = dict(
        model=settings.model,
        messages=messages,
        max_tokens=settings.max_tokens,
        temperature=settings.temperature,
        top_p=settings.top_p,
    )
    if settings.reasoning_effort is not None:
        kwargs["reasoning_effort"] = settings.reasoning_effort
    return kwargs


def stream(system_prompt: str, history: list[dict], user_message: str, model: str | None = None, reasoning_effort: str | None = None):
    """Return a Groq streaming completion iterator."""
    client = get_client()
    messages = _build_messages(system_prompt, history, user_message)
    kwargs = _base_kwargs(messages)

    active_model = model or kwargs["model"]

    if model:
        kwargs["model"] = model

    # Apply reasoning_effort only for models known to support it.
    # If the client sent an explicit value, it overrides the server default.
    _valid_efforts = {"none", "default", "low", "medium", "high"}
    if active_model in THINKING_MODELS:
        if reasoning_effort is not None and reasoning_effort in _valid_efforts:
            kwargs["reasoning_effort"] = reasoning_effort
        elif reasoning_effort is not None:
            # Unknown value — omit rather than let Groq reject the request
            kwargs.pop("reasoning_effort", None)
        # else: keep whatever _base_kwargs set (server default from env)
    else:
        kwargs.pop("reasoning_effort", None)

    kwargs["stream"] = True
    return client.chat.completions.create(**kwargs, timeout=25)

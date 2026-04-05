from groq import Groq
from app.config import get_settings

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


def stream(system_prompt: str, history: list[dict], user_message: str, model: str | None = None):
    """Return a Groq streaming completion iterator."""
    client = get_client()
    messages = _build_messages(system_prompt, history, user_message)
    kwargs = _base_kwargs(messages)
    if model:
        # User-selected model override — use it and drop reasoning_effort since
        # that parameter is only supported by specific models.
        kwargs["model"] = model
        kwargs.pop("reasoning_effort", None)
    kwargs["stream"] = True
    return client.chat.completions.create(**kwargs)

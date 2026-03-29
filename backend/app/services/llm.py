from groq import Groq
from app.config import get_settings

_client: Groq | None = None


def get_client() -> Groq:
    global _client
    if _client is None:
        settings = get_settings()
        _client = Groq(api_key=settings.groq_api_key)
    return _client


def chat(system_prompt: str, history: list[dict], user_message: str) -> str:
    settings = get_settings()
    client = get_client()

    messages = [{"role": "system", "content": system_prompt}]
    messages.extend(history)
    messages.append({"role": "user", "content": user_message})

    kwargs: dict = dict(
        model=settings.model,
        messages=messages,
        max_tokens=settings.max_tokens,
        temperature=settings.temperature,
        top_p=settings.top_p,
    )

    if settings.reasoning_effort is not None:
        kwargs["reasoning_effort"] = settings.reasoning_effort

    response = client.chat.completions.create(**kwargs)
    return response.choices[0].message.content or ""

"""Ask the small language model for one letter, A to E."""
from .config import CONFIG
from .client import post

URL = f"http://127.0.0.1:{CONFIG['LLM_PORT']}/v1/chat/completions"

# Keep the system prompt stable: llama-server caches the start of the prompt,
# so text that never changes is only read once.
SYSTEM = ("You solve multiple-choice math competition problems for school students. "
          "Read the problem and the options, then reply with the letter of the correct option.")


def format_problem(problem, sees_image=False):
    lines = [problem["text"].strip()]
    options = problem.get("options") or {}
    for letter in "ABCDE":
        if letter in options:
            lines.append(f"{letter}) {options[letter]}")
    if not options:
        lines.append("(The options are in the picture.)" if sees_image else
                     "(The options are in a picture that you can't see. Pick the most likely letter.)")
    return "\n".join(lines)


def build_messages(problem, examples=(), image_b64=None):
    """image_b64 is a PNG as base64 text. Only a server started with --mmproj can see it."""
    messages = [{"role": "system", "content": SYSTEM}]
    for ex in examples:  # solved problems retrieved with RAG, if any
        messages.append({"role": "user", "content": format_problem(ex) + "\nAnswer:"})
        messages.append({"role": "assistant", "content": ex["label"]})
    text = format_problem(problem, sees_image=bool(image_b64)) + "\nAnswer:"
    if image_b64:
        content = [{"type": "image_url", "image_url": {"url": "data:image/png;base64," + image_b64}},
                   {"type": "text", "text": text}]
    else:
        content = text
    messages.append({"role": "user", "content": content})
    return messages


def answer_letter(problem, examples=(), timeout=60, image_b64=None, url=URL):
    """Return (letter, timings). The grammar makes any other output impossible."""
    response = post(url, {
        "messages": build_messages(problem, examples, image_b64),
        "grammar": "root ::= [A-E]",
        "max_tokens": 1,
        "temperature": 0,
        "seed": int(CONFIG["SEED"]),
        "cache_prompt": True,
    }, timeout=timeout)
    letter = response["choices"][0]["message"]["content"].strip()
    return letter, response.get("timings", {})


# Numeric mode: Mathey writes one sentence of reasoning, then the number itself.
NUMBER_SYSTEM = ("You are Mathey, a math copilot for school students. "
                 "First write one short sentence with the key calculation. "
                 "Then, on a new line, write 'Answer: ' followed by only the final number, without units.")

# One sentence (up to 200 characters, ending in a period), then the number:
# an integer, a decimal or a fraction, optionally negative: 49, -3, 2.5, 3/4
NUMBER_GRAMMAR = r'''root ::= reason "\nAnswer: " number
reason ::= [^.\n]{1,200} "."
number ::= "-"? [0-9]+ ("." [0-9]+ | "/" [0-9]+)?'''


def build_number_messages(problem):
    """Only the problem text: the options are left out, so Mathey has to compute the value."""
    return [{"role": "system", "content": NUMBER_SYSTEM},
            {"role": "user", "content": problem["text"].strip()}]


def answer_number(problem, timeout=60, url=URL, max_tokens=80):
    """Return (number, reasoning, timings). number is "" if the reply was cut off."""
    response = post(url, {
        "messages": build_number_messages(problem),
        "grammar": NUMBER_GRAMMAR,
        "max_tokens": max_tokens,
        "temperature": 0,
        "seed": int(CONFIG["SEED"]),
        "cache_prompt": True,
    }, timeout=timeout)
    content = response["choices"][0]["message"]["content"].strip()
    reasoning, _, number = content.partition("\nAnswer: ")
    return number.strip(), reasoning.strip(), response.get("timings", {})

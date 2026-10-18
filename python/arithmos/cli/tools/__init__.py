from dataclasses import dataclass
from typing import Callable


@dataclass
class Tool:
    name: str
    prompt: str
    intro: str
    help: str
    handle: Callable[[str], str]
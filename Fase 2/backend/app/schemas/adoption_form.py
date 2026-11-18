from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

QuestionKind = Literal["text", "yes_no", "choice"]
AnswerValue = str | bool | None
MAX_QUESTIONS = 20
MAX_OPTIONS = 10
MAX_ANSWER_LENGTH = 1000


class FormQuestion(BaseModel):
    """Pregunta del formulario de una fundación (HU-G3).

    text: respuesta libre; yes_no: sí o no; choice: una de las alternativas de options.
    """

    label: str = Field(..., min_length=1, max_length=200)
    kind: QuestionKind
    options: list[str] = Field(default_factory=list, max_length=MAX_OPTIONS)
    required: bool = True

    @field_validator("label")
    @classmethod
    def clean_label(cls, value: str) -> str:
        value = " ".join(value.split())
        if not value:
            raise ValueError("La pregunta no puede estar vacía.")
        return value

    @field_validator("options")
    @classmethod
    def clean_options(cls, value: list[str]) -> list[str]:
        cleaned = [" ".join(option.split()) for option in value]
        if any(not option or len(option) > 100 for option in cleaned):
            raise ValueError("Cada alternativa debe tener entre 1 y 100 caracteres.")
        if len({option.casefold() for option in cleaned}) != len(cleaned):
            raise ValueError("Las alternativas no pueden repetirse.")
        return cleaned

    @model_validator(mode="after")
    def options_match_kind(self) -> "FormQuestion":
        if self.kind == "choice" and len(self.options) < 2:
            raise ValueError("Una pregunta de alternativas necesita al menos 2 opciones.")
        if self.kind != "choice" and self.options:
            raise ValueError("Solo las preguntas de alternativas llevan opciones.")
        return self


class AdoptionForm(BaseModel):
    """Formulario completo: se guarda reemplazando todas las preguntas, en el orden recibido."""

    questions: list[FormQuestion] = Field(..., max_length=MAX_QUESTIONS)


class FormAnswers(BaseModel):
    """Una respuesta por pregunta, en el mismo orden; null deja sin responder una opcional."""

    answers: list[AnswerValue] = Field(..., max_length=MAX_QUESTIONS)


class FormRequestOut(BaseModel):
    id: int
    questions: list[FormQuestion]
    answers: list[AnswerValue] | None
    answered_at: datetime | None

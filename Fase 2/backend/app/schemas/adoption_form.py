from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

QuestionKind = Literal["text", "yes_no", "choice"]
AnswerValue = str | bool | None
Decision = Literal["accepted", "rejected"]
MAX_QUESTIONS = 20
MAX_OPTIONS = 10
MAX_ANSWER_LENGTH = 1000
MAX_DECISION_MESSAGE = 1000


class FormQuestion(BaseModel):
    """Pregunta del cuestionario de adopción de una fundación (HU-G3).

    text: respuesta libre; yes_no: sí o no; choice: una de las alternativas de options.
    flagged_answers: respuestas que se marcan como "No cumple" al revisar la postulación
    (false en una de sí o no, o alternativas de options). Nunca rechazan solas: decide la fundación.
    """

    label: str = Field(..., min_length=1, max_length=200)
    kind: QuestionKind
    options: list[str] = Field(default_factory=list, max_length=MAX_OPTIONS)
    required: bool = True
    flagged_answers: list[str | bool] = Field(default_factory=list, max_length=MAX_OPTIONS)

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

    @field_validator("flagged_answers", mode="before")
    @classmethod
    def clean_flagged(cls, value):
        if not isinstance(value, list):
            return value
        return [" ".join(item.split()) if isinstance(item, str) else item for item in value]

    @model_validator(mode="after")
    def options_match_kind(self) -> "FormQuestion":
        if self.kind == "choice" and len(self.options) < 2:
            raise ValueError("Una pregunta de alternativas necesita al menos 2 opciones.")
        if self.kind != "choice" and self.options:
            raise ValueError("Solo las preguntas de alternativas llevan opciones.")
        if self.kind == "text" and self.flagged_answers:
            raise ValueError("Una pregunta de respuesta libre no puede marcar respuestas que no cumplen.")
        if self.kind == "yes_no" and any(not isinstance(item, bool) for item in self.flagged_answers):
            raise ValueError("En una pregunta de sí o no, la respuesta que no cumple debe ser sí o no.")
        if self.kind == "choice" and any(item not in self.options for item in self.flagged_answers):
            raise ValueError("Las respuestas que no cumplen deben ser alternativas de la pregunta.")
        if len(set(self.flagged_answers)) != len(self.flagged_answers):
            raise ValueError("Las respuestas que no cumplen no pueden repetirse.")
        if self.kind == "yes_no" and len(self.flagged_answers) > 1:
            raise ValueError("En una pregunta de sí o no, solo una respuesta puede no cumplir.")
        if self.kind == "choice" and len(self.flagged_answers) >= len(self.options):
            raise ValueError("Al menos una alternativa debe cumplir.")
        return self


class AdoptionForm(BaseModel):
    """Cuestionario completo: se guarda reemplazando todas las preguntas, en el orden recibido."""

    questions: list[FormQuestion] = Field(..., max_length=MAX_QUESTIONS)


class AdoptionFormOut(AdoptionForm):
    # False: son las preguntas sugeridas por Adoptify (la fundación todavía no guarda las suyas)
    customized: bool


class AnswerIn(BaseModel):
    """Respuesta a la pregunta actual del cuestionario. null salta una pregunta opcional."""

    answer: AnswerValue = None


class QuestionnaireSummary(BaseModel):
    """Estado del cuestionario de una persona para una mascota, para la lista de interesados."""

    id: int
    answered: int
    total: int
    completed: bool
    flagged: int
    decision: Decision | None


class QuestionnaireOut(BaseModel):
    """Postulación completa para la fundación: preguntas, respuestas y cuáles no cumplen."""

    id: int
    conversation_id: int
    animal_id: int
    animal_name: str
    user_id: int
    full_name: str
    questions: list[FormQuestion]
    answers: list[AnswerValue]
    # Por cada respuesta: True si es una de las que no cumplen
    flagged: list[bool]
    completed: bool
    answered_at: datetime | None
    decision: Decision | None
    decided_at: datetime | None
    created_at: datetime


class DecisionIn(BaseModel):
    """La fundación acepta o rechaza la postulación; el mensaje se envía por el chat."""

    decision: Decision
    message: str = Field(..., min_length=1, max_length=MAX_DECISION_MESSAGE)

    @field_validator("message")
    @classmethod
    def not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("El mensaje no puede estar vacío.")
        return value

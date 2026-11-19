import type { AnswerValue, Decision, FormQuestion, QuestionKind, QuestionnaireSummary } from './adoptionForm'

// Mismos límites que el backend (schemas/adoption_form.py)
export const MAX_QUESTIONS = 20
export const MAX_OPTIONS = 10
export const MAX_DECISION_MESSAGE = 1000

export const kindLabels: Record<QuestionKind, string> = { text: 'Respuesta libre', yes_no: 'Sí o no', choice: 'Alternativas' }

// En el editor las alternativas se escriben una por línea. flagged: respuestas que no cumplen
export type QuestionDraft = { label: string; kind: QuestionKind; optionsText: string; required: boolean; flagged: (string | boolean)[] }

export const emptyQuestion = (): QuestionDraft => ({ label: '', kind: 'text', optionsText: '', required: true, flagged: [] })

export const toDraft = (question: FormQuestion): QuestionDraft => ({
  label: question.label, kind: question.kind, optionsText: question.options.join('\n'), required: question.required,
  flagged: question.flagged_answers ?? [],
})

export const optionsOf = (draft: QuestionDraft) => draft.optionsText.split('\n').map(option => option.trim()).filter(Boolean)

// Lo que no cumple solo vale si sigue siendo una respuesta posible (al cambiar el tipo o borrar una alternativa)
export function flaggedOf(draft: QuestionDraft): (string | boolean)[] {
  if (draft.kind === 'yes_no') return draft.flagged.filter(item => typeof item === 'boolean').slice(0, 1)
  if (draft.kind === 'choice') {
    const options = optionsOf(draft)
    return draft.flagged.filter(item => typeof item === 'string' && options.includes(item))
  }
  return []
}

// Un mensaje por pregunta con problemas; índice → error
export function validateQuestions(drafts: QuestionDraft[]): Record<number, string> {
  const errors: Record<number, string> = {}
  drafts.forEach((draft, index) => {
    const options = optionsOf(draft)
    if (!draft.label.trim()) errors[index] = 'Escribe la pregunta.'
    else if (draft.label.trim().length > 200) errors[index] = 'La pregunta admite hasta 200 caracteres.'
    else if (draft.kind === 'choice' && options.length < 2) errors[index] = 'Agrega al menos 2 alternativas, una por línea.'
    else if (draft.kind === 'choice' && options.length > MAX_OPTIONS) errors[index] = `Máximo ${MAX_OPTIONS} alternativas.`
    else if (options.some(option => option.length > 100)) errors[index] = 'Cada alternativa admite hasta 100 caracteres.'
    else if (new Set(options.map(option => option.toLocaleLowerCase('es'))).size !== options.length) errors[index] = 'Las alternativas no pueden repetirse.'
    else if (draft.kind === 'choice' && flaggedOf(draft).length >= options.length) errors[index] = 'Al menos una alternativa debe cumplir.'
  })
  return errors
}

export function questionsPayload(drafts: QuestionDraft[]): FormQuestion[] {
  return drafts.map(draft => ({
    label: draft.label.trim(),
    kind: draft.kind,
    options: draft.kind === 'choice' ? optionsOf(draft) : [],
    required: draft.required,
    flagged_answers: flaggedOf(draft),
  }))
}

export function formatAnswer(answer: AnswerValue): string {
  if (answer === null) return 'Prefiero no responder'
  if (typeof answer === 'boolean') return answer ? 'Sí' : 'No'
  return answer
}

// Cómo se ve lo que no cumple en el editor: "No" o el nombre de la alternativa
export const flaggedLabel = (question: Pick<FormQuestion, 'flagged_answers'>) =>
  question.flagged_answers.map(item => typeof item === 'boolean' ? (item ? 'Sí' : 'No') : item).join(', ')

// Mensajes que la fundación envía al decidir; los puede editar antes de enviar
export function defaultDecisionMessage(decision: Decision, animalName: string, firstName: string): string {
  return decision === 'accepted'
    ? `¡Buenas noticias, ${firstName}! Revisamos tus respuestas y queremos avanzar con la adopción de ${animalName}. Te escribiremos por aquí para coordinar una visita.`
    : `Gracias por tu interés en ${animalName}, ${firstName}. Revisamos tus respuestas y por ahora no podemos continuar con esta adopción. Te invitamos a seguir conociendo a otras mascotas en Adoptify.`
}

// Texto corto junto al interesado: avance del cuestionario o resultado
export function questionnaireStatus(summary: QuestionnaireSummary): { text: string; tone: 'neutral' | 'danger' | 'success' } {
  if (summary.decision === 'accepted') return { text: 'Aceptada', tone: 'success' }
  if (summary.decision === 'rejected') return { text: 'Rechazada', tone: 'neutral' }
  if (!summary.completed) return { text: `Respondiendo ${summary.answered} de ${summary.total}`, tone: 'neutral' }
  if (summary.flagged === 0) return { text: 'Cumple todo', tone: 'success' }
  return { text: summary.flagged === 1 ? '1 respuesta no cumple' : `${summary.flagged} respuestas no cumplen`, tone: 'danger' }
}

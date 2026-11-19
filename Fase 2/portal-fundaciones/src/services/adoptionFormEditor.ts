import type { AnswerValue, FormQuestion, QuestionKind } from './adoptionForm'

// Mismos límites que el backend (schemas/adoption_form.py)
export const MAX_QUESTIONS = 20
export const MAX_OPTIONS = 10

export const kindLabels: Record<QuestionKind, string> = { text: 'Respuesta libre', yes_no: 'Sí o no', choice: 'Alternativas' }

// En el editor las alternativas se escriben una por línea
export type QuestionDraft = { label: string; kind: QuestionKind; optionsText: string; required: boolean }

export const emptyQuestion = (): QuestionDraft => ({ label: '', kind: 'text', optionsText: '', required: true })

export const toDraft = (question: FormQuestion): QuestionDraft =>
  ({ label: question.label, kind: question.kind, optionsText: question.options.join('\n'), required: question.required })

const optionsOf = (draft: QuestionDraft) => draft.optionsText.split('\n').map(option => option.trim()).filter(Boolean)

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
  })
  return errors
}

export function questionsPayload(drafts: QuestionDraft[]): FormQuestion[] {
  return drafts.map(draft => ({
    label: draft.label.trim(),
    kind: draft.kind,
    options: draft.kind === 'choice' ? optionsOf(draft) : [],
    required: draft.required,
  }))
}

export function formatAnswer(answer: AnswerValue): string {
  if (answer === null) return 'Sin respuesta'
  if (typeof answer === 'boolean') return answer ? 'Sí' : 'No'
  return answer
}

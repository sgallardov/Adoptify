import { api } from './api'
import type { Message } from './conversations'

// Formulario de requisitos de adopción de la fundación (HU-G3)
export type QuestionKind = 'text' | 'yes_no' | 'choice'
export type FormQuestion = { label: string; kind: QuestionKind; options: string[]; required: boolean }
export type AnswerValue = string | boolean | null
export type FormRequest = { id: number; questions: FormQuestion[]; answers: AnswerValue[] | null; answered_at: string | null }

export async function fetchAdoptionForm(signal: AbortSignal): Promise<FormQuestion[]> {
  const { data } = await api.get<{ questions: FormQuestion[] }>('/foundations/me/adoption-form', { signal })
  if (!Array.isArray(data?.questions)) throw new Error('Respuesta del formulario inválida')
  return data.questions
}

export async function saveAdoptionForm(questions: FormQuestion[]): Promise<FormQuestion[]> {
  return (await api.put<{ questions: FormQuestion[] }>('/foundations/me/adoption-form', { questions })).data.questions
}

// Crea en el chat un mensaje de tipo "form" con una copia de las preguntas actuales
export async function sendAdoptionForm(conversationId: number): Promise<Message> {
  return (await api.post<Message>(`/conversations/${conversationId}/form`)).data
}

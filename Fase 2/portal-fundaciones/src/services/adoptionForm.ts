import { api } from './api'

// Cuestionario de adopción de la fundación (HU-G3): el chat lo hace pregunta a pregunta al apretar "Conversar"
export type QuestionKind = 'text' | 'yes_no' | 'choice'
export type AnswerValue = string | boolean | null
// flagged_answers: respuestas que se marcan como "No cumple" en la postulación (false o alternativas)
export type FormQuestion = { label: string; kind: QuestionKind; options: string[]; required: boolean; flagged_answers: (string | boolean)[] }
export type AdoptionForm = { questions: FormQuestion[]; customized: boolean }
export type Decision = 'accepted' | 'rejected'

// Postulación: respuestas al cuestionario de una persona para una mascota
export type Questionnaire = {
  id: number
  conversation_id: number
  animal_id: number
  animal_name: string
  user_id: number
  full_name: string
  questions: FormQuestion[]
  answers: AnswerValue[]
  flagged: boolean[]
  completed: boolean
  answered_at: string | null
  decision: Decision | null
  decided_at: string | null
  created_at: string
}

// Lo que trae la lista de interesados para decidir si mostrar "Ver postulación"
export type QuestionnaireSummary = { id: number; answered: number; total: number; completed: boolean; flagged: number; decision: Decision | null }

function checkForm(data: AdoptionForm | undefined): AdoptionForm {
  if (!data || !Array.isArray(data.questions)) throw new Error('Respuesta del cuestionario inválida')
  return data
}

export async function fetchAdoptionForm(signal: AbortSignal): Promise<AdoptionForm> {
  return checkForm((await api.get<AdoptionForm>('/foundations/me/adoption-form', { signal })).data)
}

export async function saveAdoptionForm(questions: FormQuestion[]): Promise<AdoptionForm> {
  return checkForm((await api.put<AdoptionForm>('/foundations/me/adoption-form', { questions })).data)
}

// Borra las preguntas propias y vuelve a las sugeridas por Adoptify
export async function resetAdoptionForm(): Promise<AdoptionForm> {
  return checkForm((await api.delete<AdoptionForm>('/foundations/me/adoption-form')).data)
}

export async function fetchQuestionnaire(id: number, signal: AbortSignal): Promise<Questionnaire> {
  const { data } = await api.get<Questionnaire>(`/adoption-form-requests/${id}`, { signal })
  if (!data || !Array.isArray(data.answers)) throw new Error('Respuesta de la postulación inválida')
  return data
}

// Acepta o rechaza; el mensaje se envía por el chat
export async function decideQuestionnaire(id: number, decision: Decision, message: string): Promise<Questionnaire> {
  return (await api.post<Questionnaire>(`/adoption-form-requests/${id}/decision`, { decision, message })).data
}

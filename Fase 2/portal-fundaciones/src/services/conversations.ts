import { api } from './api'
import type { QuestionKind } from './adoptionForm'

export const MAX_MESSAGE_LENGTH = 1000
// Sondeo (HU-G2): sin WebSockets. Más seguido dentro del chat abierto que en la lista
export const MESSAGES_POLL_MS = 10_000
export const CONVERSATIONS_POLL_MS = 15_000

export type LastMessage = { body: string; created_at: string; from_foundation: boolean }

// Nunca trae correo, teléfono ni RUT del adoptante
export type Conversation = {
  id: number
  foundation_id: number
  foundation_name: string
  user_id: number
  user_name: string
  created_at: string
  last_message: LastMessage | null
}

export type Message = {
  id: number
  body: string
  created_at: string
  from_foundation: boolean
  mine: boolean
  // question: pregunta automática del cuestionario; answer: respuesta del adoptante (HU-G3)
  kind: 'text' | 'question' | 'answer'
  question: QuestionInfo | null
}

// Solo en las preguntas automáticas; index parte en 0
export type QuestionInfo = { form_id: number; animal_id: number; index: number; total: number; kind: QuestionKind; options: string[]; required: boolean }

// Abre el chat con un interesado o postulado; si ya existía, la API devuelve el mismo.
// Con animalId (Conversar desde los interesados de una mascota) empieza el cuestionario de adopción, una sola vez.
export async function openConversation(userId: number, animalId?: number): Promise<Conversation> {
  return (await api.post<Conversation>('/conversations', animalId === undefined ? { user_id: userId } : { user_id: userId, animal_id: animalId })).data
}

export async function fetchConversations(signal: AbortSignal): Promise<Conversation[]> {
  const { data } = await api.get<Conversation[]>('/conversations', { signal })
  if (!Array.isArray(data)) throw new Error('Respuesta de conversaciones inválida')
  return data
}

// Con afterId solo llegan los mensajes nuevos (para el sondeo)
export async function fetchMessages(conversationId: number, signal: AbortSignal, afterId?: number): Promise<Message[]> {
  const params = afterId === undefined ? undefined : { after_id: afterId }
  const { data } = await api.get<Message[]>(`/conversations/${conversationId}/messages`, { params, signal })
  if (!Array.isArray(data)) throw new Error('Respuesta de mensajes inválida')
  return data
}

export async function sendMessage(conversationId: number, body: string): Promise<Message> {
  return (await api.post<Message>(`/conversations/${conversationId}/messages`, { body })).data
}

import { api } from './api'
import type { QuestionnaireSummary } from './adoptionForm'
import type { AnimalStatus } from '../data/demo'

export type InterestedPerson = {
  user_id: number
  full_name: string
  favorited_at: string
  // 0-100; null si la persona no completó "Quiero adoptar"
  match_score: number | null
  // Cuestionario de adopción de esta mascota (HU-G3); null hasta que la fundación aprieta "Conversar"
  questionnaire: QuestionnaireSummary | null
}

export type AnimalInterested = {
  animal_id: number
  animal_name: string
  animal_status: AnimalStatus
  interested: InterestedPerson[]
}

// La API solo entrega nombre, id, fecha del like y match: jamás correo, teléfono ni RUT.
export async function fetchInterested(signal: AbortSignal): Promise<AnimalInterested[]> {
  const { data } = await api.get<AnimalInterested[]>('/animals/interested', { signal })
  if (!Array.isArray(data)) throw new Error('Respuesta de interesados inválida')
  return data
}

export async function fetchAnimalInterested(animalId: number, signal: AbortSignal): Promise<AnimalInterested> {
  const { data } = await api.get<AnimalInterested>(`/animals/${animalId}/interested`, { signal })
  if (!data || !Array.isArray(data.interested)) throw new Error('Respuesta de interesados inválida')
  return data
}

export const formatMatch = (score: number | null) => score === null ? 'Sin ficha de adopción' : `${Math.round(score)}\u00a0% compatible`

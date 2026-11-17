import { api } from './api'

export type InterestedPerson = {
  user_id: number
  full_name: string
  favorited_at: string
}

export type AnimalInterested = {
  animal_id: number
  animal_name: string
  animal_status: 'available' | 'in_process' | 'adopted'
  interested: InterestedPerson[]
}

// La API solo entrega nombre, id y fecha del like: jamás correo, teléfono ni RUT.
export async function fetchInterested(signal: AbortSignal): Promise<AnimalInterested[]> {
  const { data } = await api.get<AnimalInterested[]>('/animals/interested', { signal })
  if (!Array.isArray(data)) throw new Error('Respuesta de interesados inválida')
  return data
}

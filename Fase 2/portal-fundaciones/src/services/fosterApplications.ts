import { api } from './api'

// Postulaciones a hogar temporal (HU-B). Estado global y queda quién decidió. Cada fundación solo ve las de hogares
// a 10 km o menos de su sede (HU-AA).
export type FosterStatus = 'pending' | 'approved' | 'rejected'

export type FosterApplication = {
  id: number
  user_id: number
  full_name: string
  email: string
  phone: string
  address: string
  species: 'perro' | 'gato' | 'ambos'
  sizes: string[]
  space: 'casa_patio' | 'casa_sin_patio' | 'departamento'
  max_animals: number
  max_days: number
  availability: string
  // Distancia del hogar a la sede de la fundación: solo se ven postulaciones a 10 km o menos (HU-AA)
  distance_km: number
  status: FosterStatus
  decided_by_foundation_name: string | null
  decided_at: string | null
  // Pendiente, o decidida por la fundación de la sesión: solo entonces se puede aprobar, rechazar o deshacer
  can_decide: boolean
  created_at: string
}

export async function fetchFosterApplications(signal: AbortSignal): Promise<FosterApplication[]> {
  return (await api.get<FosterApplication[]>('/foster-applications', { signal })).data
}

export async function decideFosterApplication(id: number, status: FosterStatus): Promise<FosterApplication> {
  return (await api.patch<FosterApplication>(`/foster-applications/${id}`, { status })).data
}

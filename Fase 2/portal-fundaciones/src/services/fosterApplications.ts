import { api } from './api'

// Postulaciones a hogar temporal (HU-B). Estado global: lo ven todas las fundaciones y queda quién decidió.
export type FosterStatus = 'pending' | 'approved' | 'rejected'

export type FosterApplication = {
  id: number
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

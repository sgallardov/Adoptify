import { api } from './api'

export type Veterinary = {
  id: number
  name: string
  address: string | null
  commune: string | null
  phone: string | null
  opening_hours: string | null
  emergency: boolean
  latitude: number
  longitude: number
}

const santiago = { lat: -33.4489, lng: -70.6693, radius_km: 100 }

export async function fetchVeterinaries(signal: AbortSignal): Promise<Veterinary[]> {
  return (await api.get<Veterinary[]>('/veterinaries', { params: santiago, signal })).data
}

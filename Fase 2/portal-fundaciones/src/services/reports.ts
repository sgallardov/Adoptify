import { api } from './api'
import type { LatLng } from '../hooks/useMapAnimals'

export type DogReport = {
  id: number
  description: string
  photo_url: string | null
  status: string
  latitude: number
  longitude: number
  created_at: string
  distance_km?: number
}

export async function createReport(position: LatLng, description: string): Promise<DogReport> {
  const { data } = await api.post<DogReport>('/reports', { latitude: position.lat, longitude: position.lng, description })
  return data
}

export async function fetchNearbyReports(origin: LatLng, radiusKm: number, signal?: AbortSignal): Promise<DogReport[]> {
  const { data } = await api.get<DogReport[]>('/reports/nearby', {
    params: { lat: origin.lat, lng: origin.lng, radius_km: radiusKm },
    signal,
  })
  return data
}

export const reportStatuses: Record<string, string> = {
  reported: 'Reportado', in_rescue: 'En rescate', resolved: 'Resuelto',
}

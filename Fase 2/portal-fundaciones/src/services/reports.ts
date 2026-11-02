import { api } from './api'
import type { LatLng } from '../hooks/useMapAnimals'

// Reporte de una mascota abandonada. Los datos de la ficha pueden faltar en reportes antiguos.
export type DogReport = {
  id: number
  species: string | null
  size: string | null
  weight_kg: number | null
  color: string | null
  features: string | null
  condition: string | null
  behavior: string | null
  description: string
  photo_url: string | null
  status: string
  latitude: number
  longitude: number
  created_at: string
  distance_km?: number
}

export type ReportInput = {
  latitude: number; longitude: number; species: string; size: string; color: string; condition: string
  weight_kg: number | null; features: string | null; behavior: string | null; description: string; photo_url?: string
}

export async function createReport(input: ReportInput): Promise<DogReport> {
  const { data } = await api.post<DogReport>('/reports', input)
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

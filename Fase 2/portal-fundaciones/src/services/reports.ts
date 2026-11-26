import { api } from './api'

export type Report = {
  id: number; species: string | null; size: string | null; color: string | null
  description: string; status: 'reported' | 'in_rescue' | 'resolved'
  foundation_name: string | null; seen_at: string | null; taken_at: string | null
  taken_by_foundation_id: number | null
  latitude: number; longitude: number; created_at: string; distance_km?: number
}

export const reportStatusLabels: Record<Report['status'], string> = { reported: 'Reportado', in_rescue: 'En rescate', resolved: 'Resuelto' }

// Si la fundación no tiene ubicación registrada se usa Santiago como respaldo
export const FALLBACK_CENTER = { lat: -33.4489, lng: -70.6693 }
export const RADIUS_OPTIONS_KM = [10, 25, 50, 100]
export const DEFAULT_RADIUS_KM = 50

export type SearchCenter = { lat: number; lng: number; fromFoundation: boolean }

// Centro de la búsqueda: la ubicación de la fundación de la sesión; respaldo: Santiago
export async function fetchSearchCenter(signal: AbortSignal): Promise<SearchCenter> {
  try {
    const { data } = await api.get<{ latitude: number | null; longitude: number | null }>('/foundations/me', { signal })
    if (data.latitude !== null && data.longitude !== null) return { lat: data.latitude, lng: data.longitude, fromFoundation: true }
  } catch (cause) {
    if (signal.aborted) throw cause
  }
  return { ...FALLBACK_CENTER, fromFoundation: false }
}

export async function fetchReports(center: { lat: number; lng: number }, radiusKm: number, signal: AbortSignal): Promise<Report[]> {
  return (await api.get<Report[]>('/reports/nearby', { params: { lat: center.lat, lng: center.lng, radius_km: radiusKm }, signal })).data
}
// Id de la fundación de la sesión, para saber si un caso tomado es propio. null si la cuenta no tiene fundación.
export async function fetchMyFoundationId(signal: AbortSignal): Promise<number | null> {
  try {
    return (await api.get<{ id: number }>('/foundations/me', { signal })).data.id
  } catch {
    return null
  }
}
export async function takeReport(id: number): Promise<Report> {
  return (await api.put<Report>(`/reports/${id}/taken`)).data
}
export async function untakeReport(id: number): Promise<Report> {
  return (await api.delete<Report>(`/reports/${id}/taken`)).data
}
export async function resolveReport(id: number): Promise<Report> {
  return (await api.patch<Report>(`/reports/${id}/status`, { status: 'resolved' })).data
}

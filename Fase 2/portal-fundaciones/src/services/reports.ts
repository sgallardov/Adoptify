import { api } from './api'
import type { LatLng, ReportArea } from './reportArea'

export type Report = {
  id: number; species: string | null; size: string | null; color: string | null
  description: string; status: 'reported' | 'in_rescue' | 'resolved'
  foundation_name: string | null; seen_at: string | null; taken_at: string | null
  taken_by_foundation_id: number | null
  latitude: number; longitude: number; created_at: string; distance_km?: number
}

export const reportStatusLabels: Record<Report['status'], string> = { reported: 'Reportado', in_rescue: 'En rescate', resolved: 'Resuelto' }

// HU-Z: la zona de búsqueda la decide reportSearchArea, el mismo criterio que usa el mapa de la app
export async function fetchReports(area: ReportArea, signal: AbortSignal): Promise<Report[]> {
  return (await api.get<Report[]>('/reports/nearby', { params: area, signal })).data
}

// Fundación de la sesión en una sola consulta: su id, para saber si un caso tomado es propio, y la
// ubicación de su sede, que es el centro de la búsqueda de reportes (null si no la tiene registrada).
// La cuenta sin fundación (por ejemplo admin) recibe null.
export type MyFoundation = { id: number; origin: LatLng | null }

export async function fetchMyFoundation(signal: AbortSignal): Promise<MyFoundation | null> {
  try {
    const { data } = await api.get<{ id: number; latitude: number | null; longitude: number | null }>(
      '/foundations/me', { signal },
    )
    const origin = data.latitude !== null && data.longitude !== null
      ? { lat: data.latitude, lng: data.longitude }
      : null
    return { id: data.id, origin }
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

import { api } from './api'

export type Report = {
  id: number; species: string | null; size: string | null; color: string | null
  description: string; status: 'reported' | 'in_rescue' | 'resolved'
  foundation_name: string | null; seen_at: string | null; taken_at: string | null
  taken_by_foundation_id: number | null
  latitude: number; longitude: number; created_at: string; distance_km?: number
}

const santiago = { lat: -33.4489, lng: -70.6693, radius_km: 100 }

export async function fetchReports(signal: AbortSignal): Promise<Report[]> {
  return (await api.get<Report[]>('/reports/nearby', { params: santiago, signal })).data
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

import { api } from './api'

export type Report = {
  id: number; species: string | null; size: string | null; color: string | null
  description: string; status: 'reported' | 'in_rescue' | 'resolved'
  foundation_name: string | null; seen_at: string | null; taken_at: string | null
  latitude: number; longitude: number; created_at: string; distance_km?: number
}

const santiago = { lat: -33.4489, lng: -70.6693, radius_km: 100 }

export async function fetchReports(signal: AbortSignal): Promise<Report[]> {
  return (await api.get<Report[]>('/reports/nearby', { params: santiago, signal })).data
}
export async function markReportSeen(id: number): Promise<Report> {
  return (await api.post<Report>(`/reports/${id}/seen`)).data
}
export async function takeReport(id: number): Promise<Report> {
  return (await api.put<Report>(`/reports/${id}/taken`)).data
}
export async function untakeReport(id: number): Promise<Report> {
  return (await api.delete<Report>(`/reports/${id}/taken`)).data
}

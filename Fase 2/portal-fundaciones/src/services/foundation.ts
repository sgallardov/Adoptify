import { api } from './api'

export type MyFoundation = {
  id: number; name: string; description: string | null; address: string | null; commune: string | null
  city: string; phone: string | null; email: string; is_verified: boolean; photo_url: string | null
  latitude: number | null; longitude: number | null
}

export const DESCRIPTION_MIN = 20

export async function fetchMyFoundation(signal?: AbortSignal): Promise<MyFoundation> {
  return (await api.get<MyFoundation>('/foundations/me', { signal })).data
}

export async function updateMyFoundation(data: { description: string; photo_url: string | null }): Promise<MyFoundation> {
  return (await api.put<MyFoundation>('/foundations/me', data)).data
}

// Dirección legible: omite lo que no está registrado
export function locationLabel(foundation: Pick<MyFoundation, 'address' | 'commune' | 'city'>): string {
  return [foundation.address, foundation.commune, foundation.city].filter(Boolean).join(', ')
}

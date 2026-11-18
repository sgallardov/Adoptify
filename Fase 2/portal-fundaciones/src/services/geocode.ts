import { api } from './api'

// commune: comuna del catálogo reconocida en el lugar, o null
export type GeocodeResult = { label: string; latitude: number; longitude: number; commune: string | null }

// El backend consulta OpenStreetMap (Nominatim) limitado a Chile
export async function searchAddress(query: string, signal?: AbortSignal): Promise<GeocodeResult[]> {
  const { data } = await api.get<GeocodeResult[]>('/geocode', { params: { q: query }, signal })
  if (!Array.isArray(data)) throw new Error('Respuesta de direcciones inválida')
  return data
}

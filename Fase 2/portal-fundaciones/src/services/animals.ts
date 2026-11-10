import axios from 'axios'
import { api } from './api'
import { mediaUrl } from './uploads'
import type { Animal } from '../data/demo'

export type AnimalStatus = 'available' | 'in_process' | 'adopted'

export type AnimalResponse = {
  id: number
  foundation_id: number
  public_commune: string | null
  foundation_name: string | null
  name: string
  species: string
  breed: string | null
  age_months: number | null
  gender: string
  size: string
  energy_level: number
  description: string | null
  status: AnimalStatus
  photo_url: string | null
  keeping_place_type: 'refugio' | 'hogar_temporal' | null
  keeping_place_address: string | null
  latitude: number | null
  longitude: number | null
}

// POST y PATCH no devuelven el lugar de resguardo: se consulta solo desde /animals/management.
export type AnimalMutationResponse = Omit<AnimalResponse, 'keeping_place_type' | 'keeping_place_address'>


function formatAge(months: number | null): string {
  if (months === null) return 'Edad no registrada'
  if (months === 0) return 'Menos de 1 mes'
  const years = Math.floor(months / 12)
  const remaining = months % 12
  return [years ? `${years} ${years === 1 ? 'año' : 'años'}` : '', remaining ? `${remaining} ${remaining === 1 ? 'mes' : 'meses'}` : ''].filter(Boolean).join(' y ')
}

export function capitalize(text: string): string {
  return text.charAt(0).toUpperCase() + text.slice(1)
}

export const statuses: Record<AnimalStatus, string> = {
  available: 'Disponible', in_process: 'En proceso', adopted: 'Adoptado',
}

export function toAnimal(animal: AnimalResponse): Animal {
  return {
    id: animal.id, name: animal.name, species: animal.species,
    age: formatAge(animal.age_months), gender: animal.gender, size: animal.size,
    energy: animal.energy_level, status: statuses[animal.status] ?? animal.status,
    photo: mediaUrl(animal.photo_url),
    description: animal.description || 'Sin descripción registrada.',
    foundationName: animal.foundation_name,
    latitude: animal.latitude, longitude: animal.longitude,
  }
}

export type AnimalInput = Omit<AnimalResponse, 'id' | 'foundation_id' | 'foundation_name' | 'latitude' | 'longitude'> & {
  latitude?: number
  longitude?: number
  foundation_id?: number
}

export async function fetchCommunes(signal: AbortSignal): Promise<string[]> {
  return (await api.get<string[]>('/animals/communes', { signal })).data
}

export async function fetchAnimal(id: number, signal: AbortSignal): Promise<AnimalResponse | null> {
  try {
    return (await api.get<AnimalResponse>(`/animals/management/${id}`, { signal })).data
  } catch (error) {
    if (axios.isAxiosError(error) && error.response?.status === 404) return null
    throw error
  }
}

export async function createAnimal(payload: AnimalInput): Promise<AnimalMutationResponse> {
  const { data } = await api.post<AnimalMutationResponse>('/animals', payload)
  return data
}

export async function updateAnimal(id: number, payload: Partial<Omit<AnimalInput, 'foundation_id'>>): Promise<AnimalMutationResponse> {
  const { data } = await api.patch<AnimalMutationResponse>(`/animals/${id}`, payload)
  return data
}

export async function fetchAnimals(signal: AbortSignal): Promise<Animal[]> {
  const { data } = await api.get<AnimalResponse[]>('/animals/management', { signal })
  if (!Array.isArray(data)) throw new Error('Respuesta de animales inválida')
  return data.map(toAnimal)
}

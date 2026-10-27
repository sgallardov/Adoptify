import { api } from './api'
import type { Animal } from '../data/demo'

type AnimalResponse = {
  id: number
  foundation_id: number
  foundation_name: string | null
  name: string
  species: string
  age_months: number | null
  gender: string
  size: string
  energy_level: number
  description: string | null
  status: string
  photo_url: string | null
  latitude: number | null
  longitude: number | null
}

type NearbyAnimalResponse = AnimalResponse & { distance_km: number }

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

const statuses: Record<string, string> = {
  available: 'Disponible', in_process: 'En proceso', adopted: 'Adoptado',
}

function toAnimal(animal: AnimalResponse): Animal {
  return {
    id: animal.id, name: animal.name, species: animal.species,
    age: formatAge(animal.age_months), gender: animal.gender, size: animal.size,
    energy: animal.energy_level, status: statuses[animal.status] ?? animal.status,
    photo: animal.photo_url,
    description: animal.description || 'Sin descripción registrada.',
    foundationName: animal.foundation_name,
    latitude: animal.latitude, longitude: animal.longitude,
  }
}

export async function fetchAnimals(signal: AbortSignal): Promise<Animal[]> {
  const { data } = await api.get<AnimalResponse[]>('/animals', { signal })
  if (!Array.isArray(data)) throw new Error('Respuesta de animales inválida')
  return data.map(toAnimal)
}

// Animales disponibles dentro del radio, ordenados del más cercano al más lejano
export async function fetchNearbyAnimals(lat: number, lng: number, radiusKm: number, signal: AbortSignal): Promise<Animal[]> {
  const { data } = await api.get<NearbyAnimalResponse[]>('/animals/nearby', { params: { lat, lng, radius_km: radiusKm }, signal })
  if (!Array.isArray(data)) throw new Error('Respuesta de animales inválida')
  return data.map(animal => ({ ...toAnimal(animal), distanceKm: animal.distance_km }))
}

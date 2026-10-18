import axios from 'axios'
import type { Animal } from '../data/demo'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1',
  timeout: 10000,
})

type AnimalResponse = {
  id: number
  foundation_id: number
  name: string
  species: string
  age_months: number | null
  gender: string
  size: string
  energy_level: number
  description: string | null
  status: string
  photo_url: string | null
}

function formatAge(months: number | null): string {
  if (months === null) return 'Edad no registrada'
  if (months === 0) return 'Menos de 1 mes'
  const years = Math.floor(months / 12)
  const remaining = months % 12
  return [years ? `${years} ${years === 1 ? 'año' : 'años'}` : '', remaining ? `${remaining} ${remaining === 1 ? 'mes' : 'meses'}` : ''].filter(Boolean).join(' y ')
}

const statuses: Record<string, string> = {
  available: 'Disponible', in_process: 'En proceso', adopted: 'Adoptado',
}

export async function fetchAnimals(signal: AbortSignal): Promise<Animal[]> {
  const { data } = await api.get<AnimalResponse[]>('/animals', { signal })
  if (!Array.isArray(data)) throw new Error('Respuesta de animales inválida')
  return data.map(animal => ({
    id: animal.id, name: animal.name, species: animal.species,
    age: formatAge(animal.age_months), gender: animal.gender, size: animal.size,
    energy: animal.energy_level, status: statuses[animal.status] ?? animal.status,
    photo: animal.photo_url,
    description: animal.description || 'Sin descripción registrada.',
  }))
}

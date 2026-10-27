import { useEffect, useState } from 'react'
import { fetchAnimals, fetchNearbyAnimals } from '../services/animals'
import type { Animal } from '../data/demo'

export type LatLng = { lat: number; lng: number }

type Result = { key: string; animals: Animal[]; error: boolean }

// Sin origen: todas las mascotas disponibles. Con origen: las cercanas dentro del radio, ordenadas por distancia.
export function useMapAnimals(origin: LatLng | null, radiusKm: number) {
  const [attempt, setAttempt] = useState(0)
  const [result, setResult] = useState<Result | null>(null)
  // Identifica la búsqueda actual; mientras el resultado no corresponda a ella, se considera cargando
  const key = origin ? `${origin.lat},${origin.lng},${radiusKm},${attempt}` : `todas,${attempt}`

  useEffect(() => {
    const controller = new AbortController()
    const request = origin
      ? fetchNearbyAnimals(origin.lat, origin.lng, radiusKm, controller.signal)
      : fetchAnimals(controller.signal).then(list => list.filter(animal => animal.status === 'Disponible'))
    request
      .then(animals => { if (!controller.signal.aborted) setResult({ key, animals, error: false }) })
      .catch(() => { if (!controller.signal.aborted) setResult({ key, animals: [], error: true }) })
    return () => controller.abort()
  }, [key, origin, radiusKm])

  const current = result?.key === key ? result : null
  return {
    animals: current?.animals ?? [],
    loading: current === null,
    error: current?.error ?? false,
    retry: () => setAttempt(value => value + 1),
  }
}

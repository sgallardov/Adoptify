import { useEffect, useState } from 'react'
import { fetchAnimals } from '../services/animals'
import type { Animal } from '../data/demo'

export function useAnimals() {
  const [animals, setAnimals] = useState<Animal[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    const controller = new AbortController()
    setLoading(true)
    setError(false)
    fetchAnimals(controller.signal)
      .then(data => { if (!controller.signal.aborted) setAnimals(data) })
      .catch(() => { if (!controller.signal.aborted) setError(true) })
      .finally(() => { if (!controller.signal.aborted) setLoading(false) })
    return () => controller.abort()
  }, [attempt])

  return {
    animals, loading, error,
    retry: () => setAttempt(value => value + 1),
    // Reemplaza un animal ya cargado: el cambio de estado se refleja al instante, sin recargar la página (HU-Y)
    replace: (animal: Animal) => setAnimals(current => current.map(item => (item.id === animal.id ? animal : item))),
  }
}

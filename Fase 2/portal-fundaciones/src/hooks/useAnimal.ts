import { useEffect, useState } from 'react'
import { fetchAnimal } from '../services/animals'
import type { AnimalResponse } from '../services/animals'

export function useAnimal(id?: string) {
  const [attempt, setAttempt] = useState(0)
  const [result, setResult] = useState<{ key: string; animal: AnimalResponse | null; error: boolean } | null>(null)
  const key = `${id}:${attempt}`
  const validId = Boolean(id && /^\d+$/.test(id))
  useEffect(() => {
    const controller = new AbortController()
    if (!validId) return
    fetchAnimal(Number(id), controller.signal)
      .then(animal => { if (!controller.signal.aborted) setResult({ key, animal, error: false }) })
      .catch(() => { if (!controller.signal.aborted) setResult({ key, animal: null, error: true }) })
    return () => controller.abort()
  }, [id, key, validId])
  const current = result?.key === key ? result : null
  return {
    animal: current?.animal ?? null, loading: validId && current === null, error: current?.error ?? false,
    retry: () => setAttempt(value => value + 1),
    update: (animal: AnimalResponse) => setResult({ key, animal, error: false }),
  }
}

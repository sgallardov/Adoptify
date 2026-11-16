import { useEffect, useState } from 'react'
import { Heart } from 'lucide-react'
import Feedback from './Feedback'
import { fetchInterested } from '../services/interested'
import type { InterestedPerson } from '../services/interested'
import { errorMessage } from '../services/api'

export default function InterestedSection({ animalId }: { animalId: number }) {
  const [people, setPeople] = useState<InterestedPerson[] | null>(null)
  const [error, setError] = useState('')
  const [attempt, setAttempt] = useState(0)

  function retry() {
    setPeople(null)
    setError('')
    setAttempt(value => value + 1)
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchInterested(controller.signal)
      .then(groups => {
        const group = groups.find(item => item.animal_id === animalId)
        if (!controller.signal.aborted) setPeople(group?.interested ?? [])
      })
      .catch(failure => {
        if (!controller.signal.aborted) setError(errorMessage(failure, 'No pudimos cargar las personas interesadas.'))
      })
    return () => controller.abort()
  }, [animalId, attempt])

  return <section className="mt-6 border-t border-base-100 pt-6" aria-labelledby="interested-title">
    <div className="flex items-center gap-2"><Heart size={18} className="text-brand-600" /><h2 id="interested-title" className="font-semibold">Personas interesadas</h2></div>
    <p className="mt-1 text-sm text-base-500">Los favoritos muestran interés general. Para contactar a alguien, revisa sus postulaciones más abajo.</p>
    <div className="mt-4">
      {error && <Feedback kind="error" title={error} actionLabel="Reintentar" onAction={retry} compact />}
      {!error && people === null && <Feedback kind="loading" title="Cargando personas interesadas…" compact />}
      {!error && people?.length === 0 && <Feedback kind="empty" title="Aún nadie lo ha guardado" description="Los favoritos son una señal de interés, no una postulación." compact />}
      {!error && people != null && people.length > 0 && <div className="rounded-xl border border-brand-100 bg-brand-50 p-4 text-sm text-brand-900">♡ {people.length} persona{people.length === 1 ? '' : 's'} guardaron a este animal.</div>}
    </div>
  </section>
}

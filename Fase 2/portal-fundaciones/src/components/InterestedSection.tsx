import { useEffect, useState } from 'react'
import { Heart, UserRound } from 'lucide-react'
import Feedback from './Feedback'
import { fetchInterested } from '../services/interested'
import type { InterestedPerson } from '../services/interested'
import { errorMessage } from '../services/api'

function formatDate(value: string) {
  return new Intl.DateTimeFormat('es-CL', { dateStyle: 'medium' }).format(new Date(value))
}

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
    <p className="mt-1 text-sm text-base-500">Personas que marcaron este animal como favorito. Tú decides cuándo iniciar contacto.</p>
    <div className="mt-4">
      {error && <Feedback kind="error" title={error} actionLabel="Reintentar" onAction={retry} compact />}
      {!error && people === null && <Feedback kind="loading" title="Cargando personas interesadas…" compact />}
      {!error && people?.length === 0 && <Feedback kind="empty" title="Aún no hay personas interesadas" description="Cuando alguien marque este animal con un corazón, aparecerá aquí." compact />}
      {!error && people != null && people.length > 0 && <ul className="space-y-3" aria-label="Personas interesadas">
        {people.map(person => <li key={person.user_id} className="flex items-center gap-3 rounded-xl border border-base-200 bg-base-50 p-3">
          <span className="flex size-9 shrink-0 items-center justify-center rounded-full bg-brand-100 text-brand-800"><UserRound size={18} /></span>
          <div className="min-w-0"><p className="truncate text-sm font-semibold">{person.full_name}</p><p className="text-xs text-base-500">Marcó favorito el {formatDate(person.favorited_at)}</p></div>
        </li>)}
      </ul>}
    </div>
  </section>
}

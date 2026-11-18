import { useEffect, useState } from 'react'
import { Heart, MessageCircle, UserRound } from 'lucide-react'
import Feedback from './Feedback'
import { fetchAnimalInterested, formatMatch } from '../services/interested'
import type { InterestedPerson } from '../services/interested'
import { errorMessage } from '../services/api'
import { useOpenChat } from '../hooks/useOpenChat'

const formatDate = (iso: string) => new Date(iso).toLocaleDateString('es-CL', { day: 'numeric', month: 'long', year: 'numeric' })

export default function InterestedSection({ animalId }: { animalId: number }) {
  const [people, setPeople] = useState<InterestedPerson[] | null>(null)
  const [error, setError] = useState('')
  const [attempt, setAttempt] = useState(0)
  const { openChat, opening, error: chatError } = useOpenChat()

  function retry() {
    setPeople(null)
    setError('')
    setAttempt(value => value + 1)
  }

  useEffect(() => {
    const controller = new AbortController()
    fetchAnimalInterested(animalId, controller.signal)
      .then(group => { if (!controller.signal.aborted) setPeople(group.interested) })
      .catch(failure => {
        if (!controller.signal.aborted) setError(errorMessage(failure, 'No pudimos cargar las personas interesadas.'))
      })
    return () => controller.abort()
  }, [animalId, attempt])

  return <section className="mt-6 border-t border-base-100 pt-6" aria-labelledby="interested-title">
    <div className="flex items-center gap-2"><Heart size={18} className="text-brand-600" /><h2 id="interested-title" className="font-semibold">Interesados</h2></div>
    <p className="mt-1 text-sm text-base-500">Personas que marcaron a este animal con el corazón. Un favorito no inicia un chat: tú decides cuándo conversar.</p>
    <div className="mt-4">
      {error && <Feedback kind="error" title={error} actionLabel="Reintentar" onAction={retry} compact />}
      {!error && people === null && <Feedback kind="loading" title="Cargando personas interesadas…" compact />}
      {!error && people?.length === 0 && <Feedback kind="empty" title="Aún nadie lo ha marcado como favorito" description="Cuando alguien lo guarde con el corazón, aparecerá aquí." compact />}
      {!error && people != null && people.length > 0 && <>
        <ul className="space-y-3" aria-label="Lista de interesados">
          {people.map(person => <li key={person.user_id} className="flex flex-wrap items-center gap-3 rounded-2xl border border-base-200 bg-base-50 p-4">
            <UserRound size={20} aria-hidden="true" className="shrink-0 text-brand-700" />
            <div className="min-w-0 flex-1">
              <p className="text-sm font-semibold">{person.full_name}</p>
              <p className="text-xs text-base-500">Favorito desde el {formatDate(person.favorited_at)}</p>
            </div>
            <span className="rounded-full bg-brand-100 px-2.5 py-1 text-xs font-semibold text-brand-800">{formatMatch(person.match_score)}</span>
            <button type="button" disabled={opening !== null} onClick={() => openChat(person.user_id)} className="button-secondary inline-flex items-center gap-1">
              <MessageCircle size={16} aria-hidden="true" />{opening === person.user_id ? 'Abriendo…' : 'Conversar'}
            </button>
          </li>)}
        </ul>
        {chatError && <p role="alert" className="mt-3 text-sm text-danger-700">{chatError}</p>}
      </>}
    </div>
  </section>
}

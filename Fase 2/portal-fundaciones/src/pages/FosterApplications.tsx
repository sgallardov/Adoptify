import { useEffect, useState } from 'react'
import { CalendarDays, Check, Lock, Mail, MessageCircle, Phone, RotateCcw, X } from 'lucide-react'
import { decideFosterApplication, fetchFosterApplications } from '../services/fosterApplications'
import type { FosterApplication, FosterStatus } from '../services/fosterApplications'
import { capacityLabel, phoneHref, sizesLabel, spaceLabel, speciesLabel, statusLabels } from '../services/fosterLabels'
import { errorMessage } from '../services/api'
import Feedback from '../components/Feedback'
import PageHeading from '../components/PageHeading'

// "Abrir chat" depende de HU-G2 (conversaciones con user_id): se muestra cuando exista el chat
const CHAT_ENABLED = false

type Filter = FosterStatus | 'all'
const filters: { id: Filter; label: string }[] = [
  { id: 'pending', label: 'Pendientes' },
  { id: 'approved', label: 'Aprobadas' },
  { id: 'rejected', label: 'No aprobadas' },
  { id: 'all', label: 'Todas' },
]
const badgeColors: Record<FosterStatus, string> = {
  pending: 'bg-brand-50 text-brand-800',
  approved: 'bg-success-50 text-success-800',
  rejected: 'bg-base-100 text-base-600',
}
const dateFormat = new Intl.DateTimeFormat('es-CL', { day: 'numeric', month: 'short', year: 'numeric' })

export default function FosterApplications() {
  const [applications, setApplications] = useState<FosterApplication[] | null>(null)
  const [filter, setFilter] = useState<Filter>('pending')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState<number | null>(null)
  const [attempt, setAttempt] = useState(0)

  // Mismo patrón que Reportes: el aborto del doble montaje de desarrollo no es un error de red
  useEffect(() => {
    const controller = new AbortController()
    async function load() {
      setError('')
      try {
        const items = await fetchFosterApplications(controller.signal)
        if (!controller.signal.aborted) setApplications(items)
      } catch (cause) {
        if (!controller.signal.aborted) setError(errorMessage(cause, 'No pudimos cargar las postulaciones.'))
      }
    }
    void load()
    return () => controller.abort()
  }, [attempt])

  async function decide(id: number, status: FosterStatus) {
    setBusy(id)
    setError('')
    try {
      const updated = await decideFosterApplication(id, status)
      setApplications(items => items?.map(item => (item.id === id ? updated : item)) ?? null)
    } catch (cause) {
      setError(errorMessage(cause, 'No se pudo guardar la decisión.'))
      // Si otra fundación decidió o la retiraron, el listado se refresca para mostrar el estado real
      setAttempt(value => value + 1)
    } finally {
      setBusy(null)
    }
  }

  const count = (id: Filter) => applications?.filter(item => id === 'all' || item.status === id).length ?? 0
  const visible = applications?.filter(item => filter === 'all' || item.status === filter) ?? null

  return <>
    <PageHeading
      eyebrow="Hogares temporales"
      title="Postulaciones"
      description="Personas que ofrecen su hogar para cuidar temporalmente a animales rescatados. La decisión es compartida: si una fundación aprueba o rechaza, todas lo ven."
    />

    <div role="group" aria-label="Filtrar por estado" className="mb-6 flex flex-wrap gap-2">
      {filters.map(({ id, label }) => (
        <button
          key={id}
          type="button"
          aria-pressed={filter === id}
          onClick={() => setFilter(id)}
          className={`rounded-full border px-4 py-2 text-sm font-medium ${filter === id ? 'border-brand-600 bg-brand-50 text-brand-800' : 'border-base-200 bg-surface text-base-600 hover:border-base-300'}`}
        >
          {label} <span className="ml-1 text-xs opacity-80">{count(id)}</span>
        </button>
      ))}
    </div>

    {error && <div className="mb-5"><Feedback kind="error" title={error} actionLabel="Reintentar" onAction={() => setAttempt(value => value + 1)} /></div>}
    {applications === null && !error && <Feedback kind="loading" title="Cargando postulaciones…" />}
    {visible?.length === 0 && (
      <Feedback
        kind="empty"
        title={filter === 'pending' ? 'No hay postulaciones pendientes' : 'No hay postulaciones aquí'}
        description="Cuando alguien postule desde la app, aparecerá en este listado."
      />
    )}

    <div className="grid gap-4 lg:grid-cols-2">
      {visible?.map(application => (
        <article key={application.id} className="rounded-2xl border border-base-200 bg-surface p-5" aria-labelledby={`postulacion-${application.id}`}>
          <div className="flex items-start justify-between gap-3">
            <div>
              <h2 id={`postulacion-${application.id}`} className="font-semibold">{application.full_name}</h2>
              <p className="mt-1 flex items-center gap-1.5 text-xs text-base-500">
                <CalendarDays size={13} aria-hidden="true" />Postuló el {dateFormat.format(new Date(application.created_at))}
              </p>
            </div>
            <span className={`rounded-full px-3 py-1 text-xs font-semibold ${badgeColors[application.status]}`}>{statusLabels[application.status]}</span>
          </div>

          <dl className="mt-4 space-y-2 text-sm">
            <div className="flex items-center gap-2"><dt className="sr-only">Correo</dt><Mail size={15} aria-hidden="true" className="text-base-400" /><dd><a href={`mailto:${application.email}`} className="text-brand-600 hover:text-brand-700">{application.email}</a></dd></div>
            <div className="flex items-center gap-2"><dt className="sr-only">Teléfono</dt><Phone size={15} aria-hidden="true" className="text-base-400" /><dd><a href={phoneHref(application.phone)} className="text-brand-600 hover:text-brand-700">{application.phone}</a></dd></div>
            <div className="flex items-start gap-2"><dt className="sr-only">Dirección privada</dt><Lock size={15} aria-hidden="true" className="mt-0.5 text-base-400" /><dd>{application.address}<span className="block text-xs text-base-500">Dirección privada: solo la ven las fundaciones.</span></dd></div>
          </dl>

          <div className="mt-4 rounded-xl bg-base-50 p-4 text-sm leading-6 text-base-700">
            <p><span className="font-medium">{speciesLabel(application.species)}</span> · {sizesLabel(application.sizes)}</p>
            <p>{capacityLabel(application)}</p>
            <p>{spaceLabel(application.space)} · {application.availability}</p>
          </div>

          {application.status !== 'pending' && application.decided_by_foundation_name && (
            <p className={`mt-3 text-sm ${application.status === 'approved' ? 'font-medium text-success-800' : 'text-base-600'}`}>
              {statusLabels[application.status]} por {application.can_decide ? 'tu fundación' : application.decided_by_foundation_name}
            </p>
          )}

          <div className="mt-5 flex flex-wrap gap-2">
            {application.can_decide && application.status === 'pending' && <>
              <button type="button" disabled={busy === application.id} onClick={() => decide(application.id, 'approved')} className="button-primary"><Check size={16} />Aprobar</button>
              <button type="button" disabled={busy === application.id} onClick={() => decide(application.id, 'rejected')} className="button-secondary"><X size={16} />Rechazar</button>
            </>}
            {application.can_decide && application.status !== 'pending' && (
              <button type="button" disabled={busy === application.id} onClick={() => decide(application.id, 'pending')} className="button-secondary"><RotateCcw size={16} />Volver a pendiente</button>
            )}
            {CHAT_ENABLED && <button type="button" className="button-secondary"><MessageCircle size={16} />Abrir chat</button>}
          </div>
        </article>
      ))}
    </div>
  </>
}

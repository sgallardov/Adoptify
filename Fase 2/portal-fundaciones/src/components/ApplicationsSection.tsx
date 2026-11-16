import { useEffect, useState } from 'react'
import { ClipboardList, MessageCircle, UserRound } from 'lucide-react'
import Feedback from './Feedback'
import { errorMessage } from '../services/api'
import { fetchFoundationApplications, updateApplicationStatus, type AdoptionApplication } from '../services/adoptionApplications'

const statusLabel: Record<string, string> = { submitted: 'Nueva', reviewing: 'En revisión', invited_to_chat: 'Invitada a conversar', rejected: 'No continúa', approved: 'Preseleccionada' }

export default function ApplicationsSection({ animalId }: { animalId: number }) {
  const [items, setItems] = useState<AdoptionApplication[] | null>(null)
  const [error, setError] = useState('')
  const [saving, setSaving] = useState<number | null>(null)
  const load = () => {
    setError('')
    fetchFoundationApplications().then(all => setItems(all.filter(item => item.animal_id === animalId))).catch(e => setError(errorMessage(e, 'No pudimos cargar las postulaciones.')))
  }
  useEffect(load, [animalId])
  async function setStatus(item: AdoptionApplication, status: 'reviewing' | 'invited_to_chat' | 'rejected' | 'approved') {
    setSaving(item.id)
    try { const updated = await updateApplicationStatus(item.id, status); setItems(list => list?.map(value => value.id === item.id ? updated : value) ?? null) }
    catch (e) { setError(errorMessage(e, 'No pudimos actualizar la postulación.')) }
    finally { setSaving(null) }
  }
  return <section className="mt-6 border-t border-base-100 pt-6" aria-labelledby="applications-title">
    <div className="flex items-center gap-2"><ClipboardList size={18} className="text-brand-600" /><h2 id="applications-title" className="font-semibold">Postulaciones</h2></div>
    <p className="mt-1 text-sm text-base-500">Aquí aparecen solo las personas que completaron una ficha para adoptar. Los favoritos son interés general, no candidatos.</p>
    <div className="mt-4 space-y-3">
      {error && <Feedback kind="error" title={error} actionLabel="Reintentar" onAction={load} compact />}
      {!error && items === null && <Feedback kind="loading" title="Cargando postulaciones…" compact />}
      {!error && items?.length === 0 && <Feedback kind="empty" title="Aún no hay postulaciones" description="Cuando alguien complete su ficha para este animal, aparecerá aquí." compact />}
      {items?.map(item => <article key={item.id} className="rounded-2xl border border-base-200 bg-base-50 p-4">
        <div className="flex items-start justify-between gap-3"><div className="flex items-center gap-2"><UserRound size={18} className="text-brand-700" /><strong className="text-sm">{item.applicant.full_name}</strong></div><span className="rounded-full bg-brand-100 px-2 py-1 text-xs text-brand-800">{statusLabel[item.status] ?? item.status}</span></div>
        <p className="mt-3 text-sm text-base-600">Vivienda: {item.profile.housing_type.replaceAll('_', ' ')} · Mascotas: {item.profile.has_pets} · Experiencia: {item.profile.experience ?? 'No indicada'}</p>
        {item.message && <p className="mt-2 text-sm italic text-base-600">“{item.message}”</p>}
        {['submitted', 'reviewing', 'invited_to_chat'].includes(item.status) && <div className="mt-4 flex flex-wrap gap-2">
          {item.status === 'submitted' && <button type="button" className="button-secondary" disabled={saving === item.id} onClick={() => setStatus(item, 'reviewing')}>Revisar ficha</button>}
          {item.status !== 'invited_to_chat' && <button type="button" className="button-primary inline-flex items-center gap-1" disabled={saving === item.id} onClick={() => setStatus(item, 'invited_to_chat')}><MessageCircle size={16} />Invitar a conversar</button>}
          <button type="button" className="text-sm text-base-600 underline" disabled={saving === item.id} onClick={() => setStatus(item, 'rejected')}>No continuar</button>
        </div>}
      </article>)}
    </div>
  </section>
}

import { useRef, useState } from 'react'
import { Link, useLocation, useParams } from 'react-router'
import { ArrowLeft } from 'lucide-react'
import { useAnimal } from '../hooks/useAnimal'
import { statuses, toAnimal, updateAnimal } from '../services/animals'
import type { AnimalResponse, AnimalStatus } from '../services/animals'
import { animalError } from '../services/animalErrors'
import Feedback from '../components/Feedback'
import AnimalsState from '../components/AnimalsState'
import { AnimalPhoto, StatusBadge } from '../components/AnimalCard'
import NotFound from './NotFound'

export default function AnimalDetail() {
  const { id } = useParams()
  const { animal, loading, error, retry, update } = useAnimal(id)
  if (loading || error) return <AnimalsState loading={loading} retry={retry} />
  if (!animal) return <NotFound />
  return <Detail key={animal.id} record={animal} onUpdate={update} />
}

function StatusEditor({ record, onUpdate }: { record: AnimalResponse; onUpdate: (animal: AnimalResponse) => void }) {
  const [status, setStatus] = useState<AnimalStatus>(record.status)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const inFlight = useRef(false)
  async function save() {
    if (inFlight.current || status === record.status) return
    inFlight.current = true
    setSaving(true)
    setError('')
    try { onUpdate(await updateAnimal(record.id, { status })) }
    catch (failure) { setError(animalError(failure).message) }
    finally { inFlight.current = false; setSaving(false) }
  }
  return <div className="mt-6 space-y-3">
    <label htmlFor="animal-status" className="block text-sm font-semibold">Estado de adopción</label>
    <div className="flex flex-wrap gap-3">
      <select id="animal-status" value={status} onChange={event => { setStatus(event.target.value as AnimalStatus); setError('') }} disabled={saving} className="min-w-0 flex-1 rounded-xl border border-base-300 bg-surface px-3 py-2.5">
        {Object.entries(statuses).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
      </select>
      <button type="button" onClick={save} disabled={saving || status === record.status} className="button-primary">{saving ? 'Guardando…' : 'Cambiar estado'}</button>
    </div>
    {saving && <Feedback kind="loading" title="Actualizando estado…" compact />}
    {error && <Feedback kind="error" title={error} compact />}
  </div>
}

function Detail({ record, onUpdate }: { record: AnimalResponse; onUpdate: (animal: AnimalResponse) => void }) {
  const location = useLocation()
  const [notice, setNotice] = useState<string>((location.state as { notice?: string } | null)?.notice ?? '')
  const animal = toAnimal(record)

  return <>
    <Link to="/animales" className="mb-7 inline-flex items-center gap-2 text-sm text-base-600 hover:text-brand-700"><ArrowLeft size={17} />Volver a mis animales</Link>
    {notice && <div className="mb-5"><Feedback kind="success" title={notice} compact /></div>}
    <div className="grid overflow-hidden rounded-3xl border border-base-200 bg-surface md:grid-cols-2">
      <AnimalPhoto key={animal.id} animal={animal} large />
      <div className="p-7 sm:p-10">
        <StatusBadge status={animal.status} /><h1 className="mb-2 mt-4 text-4xl font-bold tracking-tight">{animal.name}</h1>
        <p className="capitalize text-base-500">{animal.species} · {animal.size}</p>
        <p className="my-7 leading-7 text-base-600">{animal.description}</p>
        <dl className="grid grid-cols-2 gap-6 border-y border-base-100 py-6">
          {[['Edad', animal.age], ['Sexo', animal.gender], ['Tamaño', animal.size], ['Energía', `${animal.energy} de 5`]].map(([label, value]) => <div key={label}><dt className="text-xs text-base-500">{label}</dt><dd className="mt-1 text-sm font-semibold">{value}</dd></div>)}
        </dl>
        <p className="mt-5 text-sm text-base-500">{record.latitude != null && record.longitude != null ? `Ubicación: ${record.latitude.toFixed(6)}, ${record.longitude.toFixed(6)}` : 'Ubicación no registrada'}</p>
        <Link to={`/animales/${animal.id}/editar`} className="button-secondary mt-5">Editar animal</Link>
        <StatusEditor key={`${record.id}-${record.status}`} record={record} onUpdate={updated => { onUpdate(updated); setNotice('El estado del animal se actualizó correctamente.') }} />
      </div>
    </div>
  </>
}

import { useState } from 'react'
import { statuses, updateAnimal } from '../services/animals'
import { animalError } from '../services/animalErrors'
import { statusOptions } from '../services/animalStatus'
import type { Animal, AnimalStatus } from '../data/demo'

/** Cambia el estado del animal desde la lista y avisa al padre para mover la tarjeta de pestaña sin recargar. */
export default function AnimalStatusSelect({ animal, onChange }: { animal: Animal; onChange: (animal: Animal) => void }) {
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const selectId = `animal-status-${animal.id}`

  async function change(status: AnimalStatus) {
    if (saving || status === animal.statusKey) return
    setSaving(true)
    setError('')
    try {
      await updateAnimal(animal.id, { status })
      onChange({ ...animal, status: statuses[status], statusKey: status })
    } catch (failure) {
      setError(animalError(failure).message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="border-t border-base-100 px-5 py-4">
      <label htmlFor={selectId} className="block text-xs font-semibold text-base-600">Estado de {animal.name}</label>
      <select
        id={selectId}
        value={animal.statusKey ?? ''}
        disabled={saving}
        onChange={event => change(event.target.value as AnimalStatus)}
        className="mt-2 w-full rounded-xl border border-base-300 bg-surface px-3 py-2 text-sm disabled:opacity-60"
      >
        {statusOptions(animal.statusKey).map(status => <option key={status} value={status}>{statuses[status]}</option>)}
      </select>
      <p aria-live="polite" className="mt-2 text-xs text-base-500">{saving ? 'Guardando el estado…' : ''}</p>
      {error && <p className="mt-1 text-xs font-semibold text-danger-700">{error}</p>}
    </div>
  )
}

import { useRef } from 'react'
import { panelId, statusTabs, tabId, tabLabels } from '../services/animalStatus'
import type { AnimalStatus } from '../data/demo'

/** Pestañas por estado con el conteo de cada una; se navegan con mouse, toque y teclado. */
export default function AnimalStatusTabs({ counts, active, onSelect }: {
  counts: Record<AnimalStatus, number>
  active: AnimalStatus
  onSelect: (status: AnimalStatus) => void
}) {
  const refs = useRef<Record<string, HTMLButtonElement | null>>({})

  function move(event: React.KeyboardEvent<HTMLButtonElement>) {
    const current = statusTabs.indexOf(active)
    const next = event.key === 'ArrowRight' ? (current + 1) % statusTabs.length
      : event.key === 'ArrowLeft' ? (current - 1 + statusTabs.length) % statusTabs.length
      : event.key === 'Home' ? 0
      : event.key === 'End' ? statusTabs.length - 1
      : -1
    if (next === -1) return
    event.preventDefault()
    const status = statusTabs[next]
    onSelect(status)
    refs.current[status]?.focus()
  }

  return (
    <div role="tablist" aria-label="Animales por estado" className="mb-6 flex flex-wrap gap-2 border-b border-base-200 pb-2">
      {statusTabs.map(status => {
        const selected = status === active
        return (
          <button
            key={status}
            ref={element => { refs.current[status] = element }}
            type="button"
            role="tab"
            id={tabId(status)}
            aria-selected={selected}
            aria-controls={panelId(status)}
            tabIndex={selected ? 0 : -1}
            onClick={() => onSelect(status)}
            onKeyDown={move}
            className={`flex items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold transition-colors ${selected ? 'bg-brand-600 text-on-accent' : 'text-base-600 hover:bg-brand-50'}`}
          >
            {tabLabels[status]}
            <span className={`rounded-full px-2 py-0.5 text-xs ${selected ? 'bg-surface/25' : 'bg-base-100 text-base-600'}`}>{counts[status]}</span>
          </button>
        )
      })}
    </div>
  )
}

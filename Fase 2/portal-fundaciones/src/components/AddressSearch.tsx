import { useRef, useState } from 'react'
import type { KeyboardEvent } from 'react'
import { MapPin, Search } from 'lucide-react'
import Feedback from './Feedback'
import type { LatLng } from './mapTiles'
import { searchAddress } from '../services/geocode'
import type { GeocodeResult } from '../services/geocode'
import { errorMessage } from '../services/api'

type Props = {
  // Texto con el que parte el buscador (por ejemplo, la dirección del lugar de resguardo)
  suggestion?: string
  onPick: (position: LatLng, commune: string | null) => void
  disabled?: boolean
}

/** Busca una dirección en Chile y entrega el punto elegido, para no escribir coordenadas a mano. */
export default function AddressSearch({ suggestion = '', onPick, disabled = false }: Props) {
  const [query, setQuery] = useState('')
  const [touched, setTouched] = useState(false)
  const [results, setResults] = useState<GeocodeResult[] | null>(null)
  const [searching, setSearching] = useState(false)
  const [error, setError] = useState('')
  const [picked, setPicked] = useState('')
  const controller = useRef<AbortController | null>(null)
  const text = touched ? query : suggestion

  async function search() {
    const value = text.trim()
    if (value.length < 3) { setError('Escribe al menos 3 caracteres de la dirección.'); setResults(null); return }
    controller.current?.abort()
    const current = new AbortController()
    controller.current = current
    setSearching(true)
    setError('')
    setResults(null)
    try {
      const found = await searchAddress(value, current.signal)
      if (!current.signal.aborted) setResults(found)
    } catch (failure) {
      if (!current.signal.aborted) setError(errorMessage(failure, 'No pudimos buscar la dirección. Inténtalo nuevamente.'))
    } finally {
      if (!current.signal.aborted) setSearching(false)
    }
  }

  function pick(result: GeocodeResult) {
    onPick({ lat: result.latitude, lng: result.longitude }, result.commune)
    setPicked(result.label)
    setResults(null)
  }

  // Enter busca en vez de enviar el formulario del animal
  function onKeyDown(event: KeyboardEvent<HTMLInputElement>) {
    if (event.key === 'Enter') { event.preventDefault(); search() }
  }

  return <div className="mb-4">
    <label htmlFor="address-search" className="text-sm font-semibold">Buscar dirección</label>
    <div className="mt-2 flex flex-col gap-2 sm:flex-row">
      <input id="address-search" type="search" value={text} disabled={disabled || searching} maxLength={200}
        onChange={event => { setTouched(true); setQuery(event.target.value); setError('') }} onKeyDown={onKeyDown}
        placeholder="Ej.: Av. Grecia 100, Ñuñoa" aria-describedby="address-search-help"
        className="min-w-0 flex-1 rounded-xl border border-base-300 bg-surface px-3 py-2.5 text-base text-base-800 disabled:opacity-60" />
      <button type="button" onClick={search} disabled={disabled || searching} className="button-secondary inline-flex items-center justify-center gap-1">
        <Search size={16} aria-hidden="true" />{searching ? 'Buscando…' : 'Buscar'}
      </button>
    </div>
    <p id="address-search-help" className="mt-2 text-xs text-base-500">Elige un resultado para mover el marcador. Después puedes ajustarlo en el mapa.</p>
    <div aria-live="polite" className="mt-2">
      {error && <Feedback kind="error" title={error} compact />}
      {results?.length === 0 && <Feedback kind="empty" title="No encontramos esa dirección" description="Prueba agregando la comuna o una calle cercana." compact />}
      {results && results.length > 0 && <ul className="divide-y divide-base-100 overflow-hidden rounded-xl border border-base-200" aria-label="Resultados de la búsqueda">
        {results.map(result => <li key={`${result.latitude},${result.longitude},${result.label}`}>
          <button type="button" onClick={() => pick(result)} className="flex w-full items-start gap-2 px-3 py-2.5 text-left text-sm hover:bg-base-50 focus-visible:bg-base-50">
            <MapPin size={16} aria-hidden="true" className="mt-0.5 shrink-0 text-brand-600" /><span>{result.label}{result.commune && <span className="mt-0.5 block text-xs font-semibold text-brand-700">Comuna: {result.commune}</span>}</span>
          </button>
        </li>)}
      </ul>}
      {picked && !results && !error && <p className="text-sm text-success-800">Marcador ubicado en: {picked}</p>}
    </div>
  </div>
}

import { useState } from 'react'
import { LoaderCircle, LocateFixed, LogOut, MapPin, PawPrint, TriangleAlert, X } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'
import { useMapAnimals } from '../hooks/useMapAnimals'
import type { LatLng } from '../hooks/useMapAnimals'
import type { Animal } from '../data/demo'
import { StatusBadge } from '../components/AnimalCard'
import { capitalize } from '../services/animals'
import AnimalsMap from '../components/AnimalsMap'
import AnimalsState from '../components/AnimalsState'
import PageHeading from '../components/PageHeading'

const RADIUS_OPTIONS = [5, 10, 25, 50, 100]

function AnimalThumb({ animal }: { animal: Animal }) {
  const [failed, setFailed] = useState(false)
  return (
    <span className="flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-stone-100">
      {failed || !animal.photo ? <PawPrint size={24} className="text-stone-300" /> : <img src={animal.photo} alt="" onError={() => setFailed(true)} loading="lazy" className="h-full w-full object-cover" />}
    </span>
  )
}

// Inicio del adoptante: mapa de mascotas disponibles y búsqueda por cercanía
export default function UserHome() {
  const { user, signOut } = useAuth()
  const [origin, setOrigin] = useState<LatLng | null>(null)
  const [radiusKm, setRadiusKm] = useState(10)
  const [locating, setLocating] = useState(false)
  const [geoError, setGeoError] = useState<string | null>(null)
  const [selectedId, setSelectedId] = useState<number | null>(null)
  const { animals, loading, error, retry } = useMapAnimals(origin, radiusKm)
  const firstName = user?.full_name.split(' ')[0] ?? ''

  function locate() {
    if (!('geolocation' in navigator)) {
      setGeoError('Tu navegador no permite obtener la ubicación.')
      return
    }
    setLocating(true)
    setGeoError(null)
    navigator.geolocation.getCurrentPosition(
      position => {
        setOrigin({ lat: position.coords.latitude, lng: position.coords.longitude })
        setSelectedId(null)
        setLocating(false)
      },
      err => {
        setGeoError(err.code === err.PERMISSION_DENIED
          ? 'No diste permiso para usar tu ubicación. Puedes activarlo en la configuración del navegador.'
          : 'No pudimos obtener tu ubicación. Inténtalo nuevamente.')
        setLocating(false)
      },
      { timeout: 10000, maximumAge: 60000 },
    )
  }

  function clearLocation() {
    setOrigin(null)
    setSelectedId(null)
  }

  const summary = origin
    ? `${animals.length} ${animals.length === 1 ? 'mascota disponible' : 'mascotas disponibles'} a menos de ${radiusKm} km`
    : `${animals.length} ${animals.length === 1 ? 'mascota disponible' : 'mascotas disponibles'}`

  return (
    <div className="min-h-screen">
      <header className="flex min-h-20 items-center justify-between gap-3 border-b border-stone-200 bg-white px-5 sm:px-9">
        <span className="flex items-center gap-2.5">
          <span className="rounded-xl bg-orange-600 p-2 text-white"><PawPrint size={22} /></span>
          <span className="text-xl font-extrabold tracking-tight">adoptify<span className="text-orange-600">.</span></span>
        </span>
        <div className="flex items-center gap-3">
          <span className="hidden text-sm text-stone-600 sm:inline">{user?.email}</span>
          <button onClick={signOut} className="inline-flex items-center gap-2 rounded-xl border border-stone-200 px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-50"><LogOut size={16} />Cerrar sesión</button>
        </div>
      </header>
      <main id="contenido" className="mx-auto max-w-7xl px-5 py-8 sm:px-9 sm:py-10">
        <PageHeading eyebrow="Mascotas cerca de ti" title={`Hola, ${firstName} 👋`} description="Explora en el mapa a las mascotas que buscan hogar y encuentra las que están más cerca de ti." />

        <div className="mb-5 flex flex-wrap items-center gap-3">
          {origin ? <>
            <label className="flex items-center gap-2 text-sm font-medium">Radio
              <select value={radiusKm} onChange={e => setRadiusKm(Number(e.target.value))} className="rounded-xl border border-stone-200 bg-white px-3 py-2 text-sm">
                {RADIUS_OPTIONS.map(km => <option key={km} value={km}>{km} km</option>)}
              </select>
            </label>
            <button onClick={clearLocation} className="inline-flex items-center gap-2 rounded-xl border border-stone-200 bg-white px-4 py-2 text-sm font-medium text-stone-700 hover:bg-stone-50"><X size={16} />Ver todas</button>
          </> : (
            <button onClick={locate} disabled={locating} className="inline-flex items-center gap-2 rounded-xl bg-orange-600 px-4 py-2.5 text-sm font-semibold text-white hover:bg-orange-700 disabled:opacity-60">
              {locating ? <LoaderCircle className="animate-spin" size={17} /> : <LocateFixed size={17} />}Usar mi ubicación
            </button>
          )}
          {!loading && !error && <p className="text-sm text-stone-500" aria-live="polite">{summary}</p>}
        </div>
        {geoError && <p role="alert" className="mb-5 flex items-start gap-2 rounded-xl bg-orange-50 p-3 text-sm text-orange-900"><TriangleAlert className="mt-0.5 shrink-0" size={16} />{geoError}</p>}

        <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_380px]">
          <section aria-label="Mapa de mascotas" className="h-[420px] lg:h-[600px]">
            <AnimalsMap animals={animals} origin={origin} selectedId={selectedId} onSelect={setSelectedId} />
          </section>

          <section aria-label="Lista de mascotas" className="lg:max-h-[600px] lg:overflow-y-auto">
            {loading || error ? <AnimalsState loading={loading} retry={retry} /> : animals.length === 0 ? (
              <div className="rounded-2xl border border-stone-200 bg-white p-8 text-center text-sm text-stone-500">
                <MapPin className="mx-auto mb-3 text-stone-300" size={30} />
                {origin ? <>No hay mascotas disponibles a menos de {radiusKm} km. Prueba con un radio mayor.</> : 'No hay mascotas disponibles por el momento.'}
              </div>
            ) : (
              <ul className="space-y-3">
                {animals.map(animal => (
                  <li key={animal.id}>
                    <button onClick={() => setSelectedId(animal.id)} aria-pressed={animal.id === selectedId}
                      className={`flex w-full items-center gap-4 rounded-2xl border bg-white p-3 text-left transition-colors hover:border-orange-300 ${animal.id === selectedId ? 'border-orange-500 ring-2 ring-orange-100' : 'border-stone-200'}`}>
                      <AnimalThumb animal={animal} />
                      <span className="min-w-0 flex-1">
                        <span className="flex items-center justify-between gap-2">
                          <span className="truncate font-bold">{animal.name}</span>
                          {animal.distanceKm != null ? <span className="shrink-0 rounded-full bg-orange-50 px-2.5 py-1 text-[11px] font-semibold text-orange-800">{animal.distanceKm.toLocaleString('es-CL')} km</span> : <StatusBadge status={animal.status} />}
                        </span>
                        <span className="mt-1 block truncate text-xs text-stone-500">{capitalize(animal.species)} · {animal.age} · {animal.size}</span>
                        {animal.foundationName && <span className="mt-0.5 block truncate text-xs text-stone-400">{animal.foundationName}</span>}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </div>
      </main>
    </div>
  )
}

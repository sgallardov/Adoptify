import { useRef, useState } from 'react'
import { Link, useLocation } from 'react-router'
import { LoaderCircle, LocateFixed, LogOut, Megaphone, X } from 'lucide-react'
import AppHeader from '../components/AppHeader'
import Feedback from '../components/Feedback'
import { useAuth } from '../hooks/useAuth'
import { useMapAnimals } from '../hooks/useMapAnimals'
import { useNearbyReports } from '../hooks/useNearbyReports'
import { SANTIAGO } from '../components/mapTiles'
import type { LatLng } from '../hooks/useMapAnimals'
import AdoptionCarousel from '../components/AdoptionCarousel'
import AnimalsMap from '../components/AnimalsMap'
import AnimalsState from '../components/AnimalsState'
import PageHeading from '../components/PageHeading'

const RADIUS_OPTIONS = [5, 10, 25, 50, 100]
// Sin tu ubicación, los reportes se buscan alrededor de Santiago con el radio máximo
const DEFAULT_REPORTS_RADIUS_KM = 100

// Inicio del adoptante: mapa de mascotas disponibles y búsqueda por cercanía
export default function UserHome() {
  const { user, signOut } = useAuth()
  const mapSection = useRef<HTMLElement>(null)
  const [origin, setOrigin] = useState<LatLng | null>(null)
  const [radiusKm, setRadiusKm] = useState(10)
  const [locating, setLocating] = useState(false)
  const [geoError, setGeoError] = useState<string | null>(null)
  const [selectedId, setSelectedId] = useState<number | null>(null)
  const { animals, loading, error, retry } = useMapAnimals(origin, radiusKm)
  const reports = useNearbyReports(origin ?? SANTIAGO, origin ? radiusKm : DEFAULT_REPORTS_RADIUS_KM)
  // Aviso de éxito al volver desde /reportar
  const justReported = Boolean((useLocation().state as { reported?: boolean } | null)?.reported)
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
      <AppHeader>
          <span className="hidden text-sm text-base-600 lg:inline">{user?.email}</span>
          <Link to="/reportar" className="inline-flex items-center gap-2 rounded-xl bg-danger-600 px-4 py-2 text-sm font-semibold text-surface hover:bg-danger-700"><Megaphone size={16} /><span className="hidden sm:inline">Reportar perro</span><span className="sm:hidden">Reportar</span></Link>
          <button onClick={signOut} className="button-secondary" aria-label="Cerrar sesión"><LogOut size={16} /><span className="hidden sm:inline">Cerrar sesión</span></button>
      </AppHeader>
      <main id="contenido" className="mx-auto max-w-7xl px-5 py-8 sm:px-9 sm:py-10">
        <PageHeading eyebrow="Mascotas cerca de ti" title={`Hola, ${firstName} 👋`} description="Explora en el mapa a las mascotas que buscan hogar y encuentra las que están más cerca de ti." />
        {justReported && <div className="mb-5"><Feedback kind="success" title="¡Gracias! Tu reporte quedó publicado en el mapa." compact /></div>}

        <div className="mb-5 flex flex-wrap items-center gap-3">
          {origin ? <>
            <label className="flex items-center gap-2 text-sm font-medium">Radio
              <select value={radiusKm} onChange={e => setRadiusKm(Number(e.target.value))} className="rounded-xl border border-base-200 bg-surface px-3 py-2 text-sm">
                {RADIUS_OPTIONS.map(km => <option key={km} value={km}>{km} km</option>)}
              </select>
            </label>
            <button onClick={clearLocation} className="inline-flex items-center gap-2 rounded-xl border border-base-200 bg-surface px-4 py-2 text-sm font-medium text-base-700 hover:bg-base-50"><X size={16} />Ver todas</button>
          </> : (
            <button onClick={locate} disabled={locating} className="inline-flex items-center gap-2 rounded-xl bg-brand-600 px-4 py-2.5 text-sm font-semibold text-surface hover:bg-brand-700 disabled:opacity-60">
              {locating ? <LoaderCircle className="animate-spin" size={17} /> : <LocateFixed size={17} />}Usar mi ubicación
            </button>
          )}
          {!loading && !error && <p className="text-sm text-base-500" aria-live="polite">{summary}</p>}
        </div>
        {geoError && <div className="mb-5"><Feedback kind="error" title={geoError} compact /></div>}

        <div className="space-y-8">
          <section ref={mapSection} aria-label="Mapa de mascotas y perros reportados" className="flex h-[380px] scroll-mt-5 flex-col gap-2 sm:h-[460px]">
            <div className="min-h-0 flex-1">
              <AnimalsMap animals={animals} reports={reports} origin={origin} selectedId={selectedId} onSelect={setSelectedId} />
            </div>
            <p className="flex flex-wrap gap-x-4 gap-y-1 text-xs text-base-500">
              <span className="inline-flex items-center gap-1.5"><span className="size-2.5 rounded-full bg-brand-600" />Mascotas en adopción</span>
              <span className="inline-flex items-center gap-1.5"><span className="size-2.5 rounded-full bg-danger-600" />Perros reportados ({reports.length})</span>
              {origin && <span className="inline-flex items-center gap-1.5"><span className="size-2.5 rounded-full bg-info-600" />Tu ubicación</span>}
            </p>
          </section>

          <section aria-labelledby="adoption-heading" className="min-w-0">
            <h2 id="adoption-heading" className="mb-2 text-2xl font-bold tracking-tight">Tu próximo compañero</h2>
            {loading || error ? <AnimalsState loading={loading} retry={retry} /> : animals.length === 0 ? (
              <Feedback kind="empty" title="No hay mascotas disponibles" description={origin ? `No hay mascotas a menos de ${radiusKm} km. Prueba con un radio mayor.` : 'Vuelve pronto para conocer nuevas historias.'} />
            ) : (
              <AdoptionCarousel animals={animals} selectedId={selectedId} onLocate={id => {
                setSelectedId(id)
                mapSection.current?.scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth', block: 'start' })
              }} />
            )}
          </section>
        </div>
      </main>
    </div>
  )
}

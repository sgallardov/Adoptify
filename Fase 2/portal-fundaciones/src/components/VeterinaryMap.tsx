import { useEffect, useState } from 'react'
import { MapContainer, Marker, Popup, TileLayer } from 'react-leaflet'
import { clinicIcon, OSM_ATTRIBUTION, OSM_TILES, SANTIAGO } from './mapTiles'
import { fetchVeterinaries } from '../services/veterinaries'
import type { Veterinary } from '../services/veterinaries'
import Feedback from './Feedback'

// Capa pública de atención veterinaria. La carga es independiente de los reportes: un fallo no impide gestionarlos.
export default function VeterinaryMap() {
  const [items, setItems] = useState<Veterinary[] | null>(null)
  const [error, setError] = useState(false)
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    const controller = new AbortController()
    fetchVeterinaries(controller.signal).then(data => {
      if (!controller.signal.aborted) { setItems(data); setError(false) }
    }).catch(() => { if (!controller.signal.aborted) setError(true) })
    return () => controller.abort()
  }, [attempt])

  return <section className="mb-8">
    <h2 className="text-lg font-bold">Veterinarias cercanas</h2>
    <p className="mt-1 text-sm text-base-600">Disponibilidad referencial. Confirma por teléfono antes de acudir.</p>
    {error && <div className="mt-4"><Feedback kind="error" title="No pudimos cargar las veterinarias." actionLabel="Reintentar" onAction={() => setAttempt(value => value + 1)} /></div>}
    {items === null && !error && <div className="mt-4"><Feedback kind="loading" title="Cargando veterinarias…" compact /></div>}
    {items && <MapContainer center={SANTIAGO} zoom={11} scrollWheelZoom className="relative z-0 mt-4 h-80 w-full overflow-hidden rounded-2xl border border-base-200">
      <TileLayer url={OSM_TILES} attribution={OSM_ATTRIBUTION} maxZoom={19} />
      {items.map(clinic => <Marker key={clinic.id} position={[clinic.latitude, clinic.longitude]} icon={clinicIcon}>
        <Popup><strong>{clinic.name}</strong><br />{[clinic.address, clinic.commune].filter(Boolean).join(', ') || 'Dirección no informada'}
          {clinic.phone && <><br /><a href={`tel:${clinic.phone.replaceAll(' ', '')}`}>{clinic.phone}</a></>}
          {clinic.emergency && <><br /><span>Atención de urgencias</span></>}
        </Popup>
      </Marker>)}
    </MapContainer>}
  </section>
}

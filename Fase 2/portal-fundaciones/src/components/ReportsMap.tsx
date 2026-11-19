import { useEffect, useState } from 'react'
import { MapContainer, Marker, Popup, TileLayer } from 'react-leaflet'
import { clinicIcon, OSM_ATTRIBUTION, OSM_TILES, PET_Z_OFFSET, reportIcon, SANTIAGO } from './mapTiles'
import { fetchVeterinaries } from '../services/veterinaries'
import type { Veterinary } from '../services/veterinaries'
import { reportStatusLabels } from '../services/reports'
import type { Report } from '../services/reports'
import Feedback from './Feedback'

const MAX_POPUP_DESCRIPTION = 140

function shorten(text: string) {
  return text.length > MAX_POPUP_DESCRIPTION ? `${text.slice(0, MAX_POPUP_DESCRIPTION - 1).trimEnd()}…` : text
}

// Mapa de Reportes cercanos: los mismos reportes que ve el adoptante en la app (no resueltos, 100 km
// alrededor de Santiago) y las veterinarias. Las fundaciones no tienen pin. Las veterinarias se cargan
// aparte: si fallan, los reportes se siguen viendo y gestionando.
export default function ReportsMap({ reports, onShowReport }: {
  reports: Report[] | null
  onShowReport: (id: number) => void
}) {
  const [clinics, setClinics] = useState<Veterinary[] | null>(null)
  const [clinicsError, setClinicsError] = useState(false)
  const [attempt, setAttempt] = useState(0)
  const [selectedClinic, setSelectedClinic] = useState<number | null>(null)

  useEffect(() => {
    const controller = new AbortController()
    fetchVeterinaries(controller.signal).then(data => {
      if (!controller.signal.aborted) { setClinics(data); setClinicsError(false) }
    }).catch(() => { if (!controller.signal.aborted) setClinicsError(true) })
    return () => controller.abort()
  }, [attempt])

  return <section className="mb-8" aria-labelledby="reports-map-title">
    <h2 id="reports-map-title" className="text-lg font-bold">Mapa de reportes</h2>
    <p className="mt-1 text-sm text-base-600">
      Los avisos de mascotas que publican las personas en la app, junto a las veterinarias cercanas (disponibilidad referencial: confirma por teléfono antes de acudir).
    </p>
    {clinicsError && <div className="mt-4"><Feedback kind="error" title="No pudimos cargar las veterinarias." actionLabel="Reintentar" onAction={() => setAttempt(value => value + 1)} compact /></div>}
    <MapContainer center={SANTIAGO} zoom={11} scrollWheelZoom className="relative z-0 mt-4 h-[42rem] max-h-[70vh] w-full overflow-hidden rounded-2xl border border-base-200">
      <TileLayer url={OSM_TILES} attribution={OSM_ATTRIBUTION} maxZoom={19} />
      {clinics?.map(clinic => <Marker key={`clinic-${clinic.id}`} position={[clinic.latitude, clinic.longitude]} icon={clinicIcon(clinic.id === selectedClinic)}
        title={clinic.name}
        eventHandlers={{ popupopen: () => setSelectedClinic(clinic.id), popupclose: () => setSelectedClinic(current => current === clinic.id ? null : current) }}>
        <Popup><strong>{clinic.name}</strong><br />{[clinic.address, clinic.commune].filter(Boolean).join(', ') || 'Dirección no informada'}
          {clinic.phone && <><br /><a href={`tel:${clinic.phone.replaceAll(' ', '')}`}>{clinic.phone}</a></>}
          {clinic.emergency && <><br /><span>Atención de urgencias</span></>}
        </Popup>
      </Marker>)}
      {/* Los reportes van encima de las veterinarias (HU-Q), como en la app */}
      {reports?.map(report => <Marker key={`report-${report.id}`} position={[report.latitude, report.longitude]}
        icon={reportIcon(report.species, report.taken_by_foundation_id !== null)} zIndexOffset={PET_Z_OFFSET}
        title={`Reporte #${report.id}: ${report.species ?? 'mascota'}`}>
        <Popup>
          <strong className="capitalize">{report.species ?? 'Mascota'} · {report.size ?? 'Tamaño no informado'}</strong>
          <br /><span>#{report.id} · {reportStatusLabels[report.status]}</span>
          {report.foundation_name && <><br /><span>Caso tomado por {report.foundation_name}</span></>}
          <br /><span>{shorten(report.description)}</span>
          <br /><button type="button" onClick={() => onShowReport(report.id)} className="mt-2 font-semibold text-brand-700 hover:underline">Ver reporte</button>
        </Popup>
      </Marker>)}
    </MapContainer>
    <ul className="mt-3 flex flex-wrap gap-x-5 gap-y-2 text-sm text-base-600" aria-label="Qué significa cada pin">
      <li className="flex items-center gap-2"><span className="inline-block size-3.5 rounded-full bg-danger-600" aria-hidden="true" />Mascota reportada</li>
      <li className="flex items-center gap-2"><span className="inline-block size-3.5 rounded-full bg-success-strong" aria-hidden="true" />Caso tomado por una fundación</li>
      <li className="flex items-center gap-2"><span className="inline-flex size-3.5 items-center justify-center rounded-full bg-danger-600 text-[10px] font-bold leading-none text-on-accent opacity-80" aria-hidden="true">+</span>Veterinaria</li>
    </ul>
  </section>
}

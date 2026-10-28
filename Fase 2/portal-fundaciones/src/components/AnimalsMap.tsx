import { useEffect, useMemo } from 'react'
import { MapContainer, Marker, Popup, TileLayer, useMap } from 'react-leaflet'
import L from 'leaflet'
import type { Animal } from '../data/demo'
import type { LatLng } from '../hooks/useMapAnimals'
import { capitalize } from '../services/animals'
import { reportStatuses } from '../services/reports'
import type { DogReport } from '../services/reports'
import { dotIcon, OSM_ATTRIBUTION, OSM_TILES, SANTIAGO } from './mapTiles'

const animalIcon = dotIcon('bg-orange-600', 20)
const selectedAnimalIcon = dotIcon('bg-orange-800', 26)
const reportIcon = dotIcon('bg-red-600', 18)
const originIcon = dotIcon('bg-sky-600 shadow-[0_0_0_6px_rgba(2,132,199,0.25)]', 16)

type Props = {
  animals: Animal[]
  reports?: DogReport[]
  origin: LatLng | null
  selectedId: number | null
  onSelect: (id: number | null) => void
}

function positionOf(animal: Animal): LatLng | null {
  return animal.latitude != null && animal.longitude != null ? { lat: animal.latitude, lng: animal.longitude } : null
}

// Ajusta la vista para que se vean todos los puntos cada vez que cambian
function FitToPoints({ points }: { points: LatLng[] }) {
  const map = useMap()

  useEffect(() => {
    if (points.length === 0) return
    if (points.length === 1) {
      map.setView(points[0], 14)
      return
    }
    map.fitBounds(L.latLngBounds(points), { padding: [60, 60] })
  }, [map, points])

  return null
}

export default function AnimalsMap({ animals, reports = [], origin, selectedId, onSelect }: Props) {
  const located = useMemo(() => animals.flatMap(animal => {
    const position = positionOf(animal)
    return position ? [{ animal, position }] : []
  }), [animals])
  // Memorizado: el mapa solo se reencuadra cuando cambian las mascotas o tu ubicación, no al seleccionar ni al llegar reportes
  const points = useMemo(() => [...located.map(({ position }) => position), ...(origin ? [origin] : [])], [located, origin])
  const selected = located.find(({ animal }) => animal.id === selectedId)

  return (
    // relative z-0: los paneles de Leaflet usan z-index altos y no deben tapar el resto de la página
    <MapContainer center={SANTIAGO} zoom={11} scrollWheelZoom
      className="relative z-0 h-full min-h-80 w-full overflow-hidden rounded-2xl border border-stone-200">
      <TileLayer url={OSM_TILES} attribution={OSM_ATTRIBUTION} maxZoom={19} />
      <FitToPoints points={points} />

      {origin && <Marker position={origin} icon={originIcon} title="Tu ubicación" zIndexOffset={-100} />}

      {reports.map(report => (
        <Marker key={`report-${report.id}`} position={{ lat: report.latitude, lng: report.longitude }} icon={reportIcon} title="Perro reportado">
          <Popup>
            <div className="max-w-56 space-y-1 text-sm text-stone-700">
              <strong className="block text-base text-red-700">Perro reportado</strong>
              <p className="!m-0">{report.description}</p>
              <p className="!m-0 text-stone-500">
                {reportStatuses[report.status] ?? report.status} · {new Date(report.created_at).toLocaleDateString('es-CL')}
              </p>
              {report.distance_km != null && <p className="!m-0 font-semibold text-red-700">A {report.distance_km.toLocaleString('es-CL')} km</p>}
            </div>
          </Popup>
        </Marker>
      ))}

      {located.map(({ animal, position }) => (
        <Marker key={animal.id} position={position} icon={animal.id === selectedId ? selectedAnimalIcon : animalIcon} title={animal.name}
          zIndexOffset={animal.id === selectedId ? 1000 : 0} eventHandlers={{ click: () => onSelect(animal.id) }} />
      ))}

      {selected && (
        <Popup position={selected.position} offset={[0, -8]} eventHandlers={{ remove: () => onSelect(null) }}>
          <div className="max-w-56 space-y-1 text-sm text-stone-700">
            <strong className="block text-base">{selected.animal.name}</strong>
            {selected.animal.photo && <img src={selected.animal.photo} alt="" className="mb-2 aspect-[16/10] w-full rounded-lg object-cover" />}
            <p className="!m-0">{capitalize(selected.animal.species)} · {selected.animal.age} · {selected.animal.size}</p>
            {selected.animal.foundationName && <p className="!m-0 text-stone-500">{selected.animal.foundationName}</p>}
            {selected.animal.distanceKm != null && <p className="!m-0 font-semibold text-orange-700">A {selected.animal.distanceKm.toLocaleString('es-CL')} km de ti</p>}
          </div>
        </Popup>
      )}
    </MapContainer>
  )
}

import { useEffect, useMemo } from 'react'
import { AdvancedMarker, APIProvider, InfoWindow, Map, Pin, useMap } from '@vis.gl/react-google-maps'
import { MapPinOff } from 'lucide-react'
import type { Animal } from '../data/demo'
import type { LatLng } from '../hooks/useMapAnimals'
import { capitalize } from '../services/animals'

const API_KEY: string | undefined = import.meta.env.VITE_GOOGLE_MAPS_API_KEY
// Los marcadores avanzados requieren un Map ID; DEMO_MAP_ID sirve para desarrollo
const MAP_ID: string = import.meta.env.VITE_GOOGLE_MAPS_MAP_ID || 'DEMO_MAP_ID'
const SANTIAGO: LatLng = { lat: -33.4489, lng: -70.6693 }

type Props = {
  animals: Animal[]
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
    if (!map || points.length === 0) return
    if (points.length === 1) {
      map.setCenter(points[0])
      map.setZoom(14)
      return
    }
    const bounds = new google.maps.LatLngBounds()
    points.forEach(point => bounds.extend(point))
    map.fitBounds(bounds, 60)
  }, [map, points])

  return null
}

export default function AnimalsMap({ animals, origin, selectedId, onSelect }: Props) {
  const located = useMemo(() => animals.flatMap(animal => {
    const position = positionOf(animal)
    return position ? [{ animal, position }] : []
  }), [animals])
  // Memorizado: el mapa solo se reencuadra cuando cambian las mascotas o tu ubicación, no al seleccionar
  const points = useMemo(() => [...located.map(({ position }) => position), ...(origin ? [origin] : [])], [located, origin])
  const selected = located.find(({ animal }) => animal.id === selectedId)

  if (!API_KEY) {
    return (
      <div role="note" className="flex h-full min-h-80 flex-col items-center justify-center gap-3 rounded-2xl border border-dashed border-stone-300 bg-white p-8 text-center">
        <MapPinOff className="text-stone-400" size={36} />
        <p className="font-semibold">El mapa aún no está configurado</p>
        <p className="max-w-sm text-sm leading-6 text-stone-500">Agrega <code className="rounded bg-stone-100 px-1.5 py-0.5 text-xs">VITE_GOOGLE_MAPS_API_KEY</code> en <code className="rounded bg-stone-100 px-1.5 py-0.5 text-xs">.env.local</code> y reinicia el servidor. La lista sigue funcionando.</p>
      </div>
    )
  }

  return (
    <APIProvider apiKey={API_KEY} language="es" region="CL">
      <Map mapId={MAP_ID} defaultCenter={SANTIAGO} defaultZoom={11} gestureHandling="greedy" clickableIcons={false}
        className="h-full min-h-80 w-full overflow-hidden rounded-2xl border border-stone-200">
        <FitToPoints points={points} />

        {origin && (
          <AdvancedMarker position={origin} title="Tu ubicación" zIndex={0}>
            <span className="block size-4 rounded-full border-[3px] border-white bg-sky-600 shadow-[0_0_0_6px_rgba(2,132,199,0.25)]" />
          </AdvancedMarker>
        )}

        {located.map(({ animal, position }) => (
          <AdvancedMarker key={animal.id} position={position} title={animal.name} onClick={() => onSelect(animal.id)} zIndex={animal.id === selectedId ? 2 : 1}>
            <Pin background={animal.id === selectedId ? '#9a3412' : '#ea580c'} borderColor="#7c2d12" glyphColor="#ffffff" scale={animal.id === selectedId ? 1.25 : 1} />
          </AdvancedMarker>
        ))}

        {selected && (
          <InfoWindow position={selected.position} pixelOffset={[0, -40]} onCloseClick={() => onSelect(null)} headerContent={<strong className="text-base">{selected.animal.name}</strong>}>
            <div className="max-w-56 space-y-1 text-sm text-stone-700">
              {selected.animal.photo && <img src={selected.animal.photo} alt="" className="mb-2 aspect-[16/10] w-full rounded-lg object-cover" />}
              <p>{capitalize(selected.animal.species)} · {selected.animal.age} · {selected.animal.size}</p>
              {selected.animal.foundationName && <p className="text-stone-500">{selected.animal.foundationName}</p>}
              {selected.animal.distanceKm != null && <p className="font-semibold text-orange-700">A {selected.animal.distanceKm.toLocaleString('es-CL')} km de ti</p>}
            </div>
          </InfoWindow>
        )}
      </Map>
    </APIProvider>
  )
}

import { useEffect } from 'react'
import { MapContainer, Marker, TileLayer, useMap, useMapEvents } from 'react-leaflet'
import type { LatLng } from '../hooks/useMapAnimals'
import { dotIcon, OSM_ATTRIBUTION, OSM_TILES, SANTIAGO } from './mapTiles'

const reportIcon = dotIcon('bg-danger-600', 22)

type Props = { value: LatLng | null; onChange: (position: LatLng) => void }

// Marca el punto donde el usuario hace clic
function ClickToPlace({ onChange }: Pick<Props, 'onChange'>) {
  useMapEvents({ click: event => onChange({ lat: event.latlng.lat, lng: event.latlng.lng }) })
  return null
}

// Centra el mapa en el punto marcado (por ejemplo, al usar la ubicación del GPS)
function FollowValue({ value }: Pick<Props, 'value'>) {
  const map = useMap()

  useEffect(() => {
    if (value) map.setView(value, Math.max(map.getZoom(), 16))
  }, [map, value])

  return null
}

export default function ReportLocationPicker({ value, onChange }: Props) {
  return (
    <MapContainer center={value ?? SANTIAGO} zoom={12} scrollWheelZoom
      className="relative z-0 h-80 w-full cursor-crosshair overflow-hidden rounded-2xl border border-base-200 sm:h-96">
      <TileLayer url={OSM_TILES} attribution={OSM_ATTRIBUTION} maxZoom={19} />
      <ClickToPlace onChange={onChange} />
      <FollowValue value={value} />
      {value && (
        <Marker position={value} icon={reportIcon} title="Ubicación del perro" draggable
          eventHandlers={{ dragend: event => onChange(event.target.getLatLng()) }} />
      )}
    </MapContainer>
  )
}

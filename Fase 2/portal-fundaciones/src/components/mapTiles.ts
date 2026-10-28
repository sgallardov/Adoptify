import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import type { LatLng } from '../hooks/useMapAnimals'

export const SANTIAGO: LatLng = { lat: -33.4489, lng: -70.6693 }

// Mosaicos públicos de OpenStreetMap: gratis, sin API key, con política de uso justo.
// Si el tráfico crece, basta con cambiar esta URL por la de un proveedor de mosaicos.
export const OSM_TILES = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
// OpenStreetMap exige mostrar la atribución en el mapa
export const OSM_ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'

// Pines dibujados con HTML: evita el problema de los íconos por defecto de Leaflet con Vite
export function dotIcon(className: string, size: number) {
  return L.divIcon({
    className: '',
    html: `<span class="block rounded-full border-[3px] border-white shadow-md ${className}" style="width:${size}px;height:${size}px"></span>`,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
    popupAnchor: [0, -size / 2],
  })
}

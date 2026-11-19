import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

export type LatLng = { lat: number; lng: number }

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
    html: `<span class="block rounded-full border-[3px] border-on-accent shadow-md ${className}" style="width:${size}px;height:${size}px"></span>`,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
    popupAnchor: [0, -size / 2],
  })
}

// Jerarquía de pines (HU-Q, igual que MapPins en la app): las mascotas son los más grandes y van encima;
// veterinarias y fundaciones son chicas y atenuadas, y crecen al seleccionarlas.
export const PET_PIN_SIZE = 36
export const PLACE_PIN_SIZE = 24
export const PLACE_PIN_SELECTED_SIZE = 40
// Las mascotas se dibujan sobre cualquier otro pin (zIndexOffset de Leaflet)
export const PET_Z_OFFSET = 1000

// Pin de veterinaria: cruz blanca sobre el rojo de emergencias, chico y con menos contraste
export function clinicIcon(selected = false) {
  const size = selected ? PLACE_PIN_SELECTED_SIZE : PLACE_PIN_SIZE
  return L.divIcon({
    className: '',
    html: `<span class="flex items-center justify-center rounded-full border-2 border-on-accent bg-danger-600 font-bold leading-none text-on-accent shadow ${selected ? '' : 'opacity-80'}" style="width:${size}px;height:${size}px;font-size:${Math.round(size * 0.6)}px">+</span>`,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
    popupAnchor: [0, -size / 2],
  })
}

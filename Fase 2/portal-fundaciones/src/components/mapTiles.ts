import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

export type { LatLng } from '../services/reportArea'

// La define el criterio común de reportes (HU-Z); se reexporta para los mapas que la usan como centro
export { SANTIAGO } from '../services/reportArea'

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

// Huella (PawPrint de lucide) y visto en blanco, para dibujarlos dentro de los pines HTML
const PAW_SVG = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="11" cy="4" r="2"/><circle cx="18" cy="8" r="2"/><circle cx="20" cy="16" r="2"/><path d="M9 10a5 5 0 0 1 5 5v3.5a3.5 3.5 0 0 1-6.84 1.045Q6.52 17.48 4.46 16.84A3.5 3.5 0 0 1 5.5 10Z"/></svg>'
const CHECK_SVG = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 6 9 17l-5-5"/></svg>'

const reportIcons = new Map<string, L.DivIcon>()

// Pin de un reporte, igual que MapPins.reportFor en la app: círculo café con la huella si es perro o gato
// (punto liso si es otra especie) e insignia verde con un visto si una fundación ya tomó el caso.
// Se guarda cada ícono para que volver a dibujar la página no reemplace el pin (y no cierre su popup).
export function reportIcon(species: string | null, taken = false) {
  const key = `${species === 'perro' || species === 'gato' ? 'paw' : 'dot'}-${taken}`
  let icon = reportIcons.get(key)
  if (!icon) {
    const paw = key.startsWith('paw') ? PAW_SVG : ''
    const badge = taken
      ? `<span class="absolute -right-1.5 -top-1.5 flex size-4 items-center justify-center rounded-full border-[1.5px] border-on-accent bg-success-strong text-on-accent">${CHECK_SVG}</span>`
      : ''
    icon = L.divIcon({
      className: '',
      html: `<span class="relative flex items-center justify-center rounded-full border-[3px] border-on-accent bg-alert text-on-accent shadow-md" style="width:${PET_PIN_SIZE}px;height:${PET_PIN_SIZE}px">${paw}${badge}</span>`,
      iconSize: [PET_PIN_SIZE, PET_PIN_SIZE],
      iconAnchor: [PET_PIN_SIZE / 2, PET_PIN_SIZE / 2],
      popupAnchor: [0, -PET_PIN_SIZE / 2],
    })
    reportIcons.set(key, icon)
  }
  return icon
}

// Pin de veterinaria: cruz blanca sobre el rojo de emergencias (el café es de los avisos), chico y con
// menos contraste
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

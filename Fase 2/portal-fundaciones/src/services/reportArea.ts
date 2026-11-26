export type LatLng = { lat: number; lng: number }

export const SANTIAGO: LatLng = { lat: -33.4489, lng: -70.6693 }

// HU-Z: criterio común de búsqueda de reportes entre el portal de fundaciones y la app de usuario.
// Las dos vistas piden GET /reports/nearby con estos mismos parámetros, así que con la misma ubicación
// y el mismo radio muestran exactamente los mismos reportes (los no resueltos).
//   - Con ubicación (la sede de la fundación en el portal, la del teléfono en la app): el radio elegido,
//     por defecto DEFAULT_REPORT_RADIUS_KM.
//   - Sin ubicación (cuenta sin sede geolocalizada, o permiso de ubicación denegado): Santiago con
//     NO_LOCATION_RADIUS_KM, el radio máximo que acepta la API.
// El equivalente en la app es reportSearchArea de features/map/map_service.dart: mantener los dos iguales.
export const REPORT_RADIUS_OPTIONS = [5, 10, 25, 50, 100]
export const DEFAULT_REPORT_RADIUS_KM = 10
export const NO_LOCATION_RADIUS_KM = 100

export type ReportArea = { lat: number; lng: number; radius_km: number }

export function reportSearchArea(origin: LatLng | null, radiusKm: number = DEFAULT_REPORT_RADIUS_KM): ReportArea {
  if (!origin) return { ...SANTIAGO, radius_km: NO_LOCATION_RADIUS_KM }
  return { lat: origin.lat, lng: origin.lng, radius_km: radiusKm }
}

import { useEffect, useState } from 'react'
import { fetchNearbyReports } from '../services/reports'
import type { DogReport } from '../services/reports'
import type { LatLng } from './useMapAnimals'

// Reportes de perros abandonados activos cerca de un punto. Si falla, el mapa sigue funcionando sin ellos.
export function useNearbyReports(origin: LatLng, radiusKm: number) {
  const [reports, setReports] = useState<DogReport[]>([])

  useEffect(() => {
    const controller = new AbortController()
    fetchNearbyReports(origin, radiusKm, controller.signal)
      .then(list => { if (!controller.signal.aborted) setReports(list) })
      .catch(() => { if (!controller.signal.aborted) setReports([]) })
    return () => controller.abort()
  }, [origin, radiusKm])

  return reports
}

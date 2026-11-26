import assert from 'node:assert/strict'
import test from 'node:test'
import {
  DEFAULT_REPORT_RADIUS_KM, NO_LOCATION_RADIUS_KM, REPORT_RADIUS_OPTIONS, SANTIAGO, reportSearchArea,
} from '../src/services/reportArea.ts'

// El mismo criterio que la app (reportSearchArea en features/map/map_service.dart): si estos valores
// cambian acá, hay que cambiarlos allá (lo revisa report_area_test.dart en la app).
test('el criterio común es el mismo que el de la app', () => {
  assert.deepEqual(REPORT_RADIUS_OPTIONS, [5, 10, 25, 50, 100])
  assert.equal(DEFAULT_REPORT_RADIUS_KM, 10)
  assert.equal(NO_LOCATION_RADIUS_KM, 100)
  assert.deepEqual(SANTIAGO, { lat: -33.4489, lng: -70.6693 })
})

test('con ubicación busca ahí con el radio elegido', () => {
  const sede = { lat: -33.45, lng: -70.65 }
  assert.deepEqual(reportSearchArea(sede, 25), { lat: -33.45, lng: -70.65, radius_km: 25 })
})

test('sin radio usa el radio por defecto, igual que la app', () => {
  assert.deepEqual(reportSearchArea({ lat: -36.82, lng: -73.05 }), {
    lat: -36.82, lng: -73.05, radius_km: DEFAULT_REPORT_RADIUS_KM,
  })
})

test('sin ubicación busca en Santiago con el radio máximo, aunque se haya elegido otro', () => {
  const sinUbicacion = { ...SANTIAGO, radius_km: NO_LOCATION_RADIUS_KM }
  assert.deepEqual(reportSearchArea(null), sinUbicacion)
  assert.deepEqual(reportSearchArea(null, 5), sinUbicacion)
})

test('el radio pedido es uno de los que ofrece la interfaz y lo acepta la API (1 a 100 km)', () => {
  for (const km of REPORT_RADIUS_OPTIONS) {
    const area = reportSearchArea(SANTIAGO, km)
    assert.ok(area.radius_km > 0 && area.radius_km <= 100)
  }
  assert.ok(REPORT_RADIUS_OPTIONS.includes(DEFAULT_REPORT_RADIUS_KM))
})

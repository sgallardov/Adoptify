import assert from 'node:assert/strict'
import test from 'node:test'
import { canResolve, reportAction } from '../src/services/reportActions.ts'

test('un reporte abierto y libre solo ofrece Lo tomamos', () => {
  assert.equal(reportAction({ status: 'reported', taken_by_foundation_id: null }, 1), 'take')
})
test('el caso de mi fundación ofrece Deshacer toma', () => {
  assert.equal(reportAction({ status: 'in_rescue', taken_by_foundation_id: 1 }, 1), 'untake')
})
test('un caso de otra fundación no ofrece acciones', () => {
  assert.equal(reportAction({ status: 'in_rescue', taken_by_foundation_id: 2 }, 1), null)
  assert.equal(reportAction({ status: 'in_rescue', taken_by_foundation_id: 2 }, null), null)
})
test('un reporte resuelto no ofrece acciones', () => {
  assert.equal(reportAction({ status: 'resolved', taken_by_foundation_id: null }, 1), null)
  assert.equal(reportAction({ status: 'resolved', taken_by_foundation_id: 1 }, 1), null)
})
test('solo la fundación que tomó el caso en rescate puede resolverlo', () => {
  assert.equal(canResolve({ status: 'in_rescue', taken_by_foundation_id: 1 }, 1), true)
  assert.equal(canResolve({ status: 'in_rescue', taken_by_foundation_id: 2 }, 1), false)
  assert.equal(canResolve({ status: 'reported', taken_by_foundation_id: null }, 1), false)
  assert.equal(canResolve({ status: 'resolved', taken_by_foundation_id: 1 }, 1), false)
  assert.equal(canResolve({ status: 'in_rescue', taken_by_foundation_id: 1 }, null), false)
})

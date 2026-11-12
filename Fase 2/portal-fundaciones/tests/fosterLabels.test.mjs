import assert from 'node:assert/strict'
import test from 'node:test'
import { capacityLabel, phoneHref, sizesLabel, spaceLabel, speciesLabel, statusLabels } from '../src/services/fosterLabels.ts'

test('los tamaños quedan en orden y en español', () => {
  assert.equal(sizesLabel(['grande', 'pequeño']), 'Pequeño y grande')
  assert.equal(sizesLabel(['mediano', 'grande', 'pequeño']), 'Pequeño, mediano y grande')
  assert.equal(sizesLabel(['mediano']), 'Mediano')
})
test('capacidad en singular y plural', () => {
  assert.equal(capacityLabel({ max_animals: 1, max_days: 1 }), 'Hasta 1 animal a la vez · máx. 1 día')
  assert.equal(capacityLabel({ max_animals: 3, max_days: 30 }), 'Hasta 3 animales a la vez · máx. 30 días')
})
test('especie, espacio y estado en español', () => {
  assert.equal(speciesLabel('ambos'), 'Perros y gatos')
  assert.equal(spaceLabel('casa_sin_patio'), 'Casa sin patio')
  assert.equal(statusLabels.rejected, 'No aprobada')
})
test('el enlace de teléfono deja solo + y dígitos', () => {
  assert.equal(phoneHref('+56 9 1234-5678'), 'tel:+56912345678')
})

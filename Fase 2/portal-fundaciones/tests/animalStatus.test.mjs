import assert from 'node:assert/strict'
import test from 'node:test'
import { countByStatus, inStatus, panelId, statusOptions, statusOf, statuses, statusTabs, tabLabels } from '../src/services/animalStatus.ts'

const animal = (id, statusKey) => ({ id, name: `Animal ${id}`, species: 'perro', age: '1 año', gender: 'macho', size: 'mediano', energy: 3, status: statuses[statusKey] ?? 'Disponible', statusKey, photo: null, description: '' })

const todos = [animal(1, 'available'), animal(2, 'available'), animal(3, 'in_process'), animal(4, 'adopted'), animal(5, 'follow_up')]

test('hay una pestaña por estado, con Seguimiento al final', () => {
  assert.deepEqual(statusTabs, ['available', 'in_process', 'adopted', 'follow_up'])
  assert.deepEqual(statusTabs.map(status => tabLabels[status]), ['Disponibles', 'En proceso', 'Adoptados', 'Seguimiento'])
  assert.deepEqual(statusTabs.map(status => statuses[status]), ['Disponible', 'En proceso', 'Adoptado', 'Seguimiento'])
})

test('el conteo reparte cada animal en una sola pestaña', () => {
  const counts = countByStatus(todos)
  assert.deepEqual(counts, { available: 2, in_process: 1, adopted: 1, follow_up: 1 })
  assert.equal(statusTabs.reduce((total, status) => total + counts[status], 0), todos.length)
  for (const status of statusTabs) {
    assert.equal(inStatus(todos, status).length, counts[status])
  }
})

test('un animal adoptado pasa a Seguimiento y vuelve a Adoptados sin aparecer dos veces', () => {
  const adoptado = animal(4, 'adopted')
  const enSeguimiento = { ...adoptado, statusKey: 'follow_up', status: statuses.follow_up }
  assert.deepEqual(inStatus([enSeguimiento], 'adopted'), [])
  assert.deepEqual(inStatus([enSeguimiento], 'follow_up'), [enSeguimiento])
  const vuelta = { ...enSeguimiento, statusKey: 'adopted', status: statuses.adopted }
  assert.deepEqual(inStatus([vuelta], 'adopted'), [vuelta])
  assert.deepEqual(inStatus([vuelta], 'follow_up'), [])
})

test('las pestañas vacías cuentan cero y no se quedan sin conteo', () => {
  assert.deepEqual(countByStatus([]), { available: 0, in_process: 0, adopted: 0, follow_up: 0 })
})

test('Seguimiento solo se ofrece a un animal adoptado o ya en seguimiento', () => {
  assert.deepEqual(statusOptions('available'), ['available', 'in_process', 'adopted'])
  assert.deepEqual(statusOptions('in_process'), ['available', 'in_process', 'adopted'])
  assert.deepEqual(statusOptions('adopted'), ['available', 'in_process', 'adopted', 'follow_up'])
  assert.deepEqual(statusOptions('follow_up'), ['available', 'in_process', 'adopted', 'follow_up'])
  assert.deepEqual(statusOptions(undefined), ['available', 'in_process', 'adopted'])
})

test('los datos de maqueta sin estado del backend se tratan como disponibles', () => {
  assert.equal(statusOf({ ...animal(9, 'available'), statusKey: undefined }), 'available')
})

test('cada pestaña apunta a su propio panel', () => {
  assert.deepEqual(statusTabs.map(panelId), ['panel-available', 'panel-in_process', 'panel-adopted', 'panel-follow_up'])
})

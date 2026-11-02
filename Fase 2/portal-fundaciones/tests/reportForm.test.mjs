import assert from 'node:assert/strict'
import test from 'node:test'
import { reportCondition, reportFields, reportPayload, reportSummary, toggleCondition, toggleOption, validateReport } from '../src/services/reportForm.ts'

const position = { lat: -33.4378, lng: -70.6505 }
const valid = () => ({ ...reportFields(), species: 'perro', size: 'mediano', color: ' Café ', conditions: ['herido'], description: ' Cojea cerca del paradero ' })

test('exige ubicación, tipo, tamaño, color, estado y comentarios', () => {
  const errors = validateReport(reportFields(), null)
  assert.deepEqual(Object.keys(errors).sort(), ['color', 'conditions', 'description', 'position', 'size', 'species'])
})
test('peso, características y comportamiento son opcionales', () => {
  assert.deepEqual(validateReport(valid(), position), {})
  const payload = reportPayload(valid(), position, null)
  assert.equal(payload.color, 'Café')
  assert.equal(payload.description, 'Cojea cerca del paradero')
  assert.equal(payload.weight_kg, null)
  assert.equal(payload.features, null)
  assert.deepEqual(payload.behaviors, [])
  assert.deepEqual(payload.conditions, ['herido'])
  assert.ok(!Object.hasOwn(payload, 'photo_url'))
})
test('acepta el peso con coma decimal y rechaza pesos fuera de rango', () => {
  const fields = { ...valid(), weight_kg: '3,5' }
  assert.deepEqual(validateReport(fields, position), {})
  assert.equal(reportPayload(fields, position, 'uploads/a.jpg').weight_kg, 3.5)
  assert.ok(validateReport({ ...valid(), weight_kg: '0' }, position).weight_kg)
  assert.ok(validateReport({ ...valid(), weight_kg: '200' }, position).weight_kg)
  assert.ok(validateReport({ ...valid(), weight_kg: 'mucho' }, position).weight_kg)
})
test('envía latitud y longitud sin invertirlas', () => {
  const payload = reportPayload(valid(), position, null)
  assert.equal(payload.latitude, -33.4378)
  assert.equal(payload.longitude, -70.6505)
})
test('resume la ficha en español y tolera reportes antiguos sin datos', () => {
  const report = { species: 'gato', size: 'pequeño', weight_kg: 3.5, color: 'Negro', conditions: ['desnutrido', 'herido'], behaviors: ['asustado'] }
  assert.equal(reportSummary(report), 'Gato · Pequeño · Negro · ~3,5 kg')
  assert.equal(reportCondition(report), 'Desnutrido, Herido · Asustado')
  const old = { species: null, size: null, weight_kg: null, color: null, conditions: [], behaviors: [] }
  assert.equal(reportSummary(old), '')
  assert.equal(reportCondition(old), '')
})
test('permite varios estados, pero "Bien" no se combina con otros', () => {
  assert.deepEqual(toggleCondition(['herido'], 'desnutrido'), ['herido', 'desnutrido'])
  assert.deepEqual(toggleCondition(['herido', 'desnutrido'], 'herido'), ['desnutrido'])
  assert.deepEqual(toggleCondition(['herido', 'enfermo'], 'bien'), ['bien'])
  assert.deepEqual(toggleCondition(['bien'], 'herido'), ['herido'])
  assert.ok(validateReport({ ...valid(), conditions: ['bien', 'herido'] }, position).conditions)
  assert.deepEqual(validateReport({ ...valid(), conditions: ['herido', 'enfermo'] }, position), {})
})
test('permite varios comportamientos o ninguno', () => {
  assert.deepEqual(toggleOption([], 'asustado'), ['asustado'])
  assert.deepEqual(toggleOption(['asustado'], 'agresivo'), ['asustado', 'agresivo'])
  assert.deepEqual(toggleOption(['asustado', 'agresivo'], 'asustado'), ['agresivo'])
  assert.deepEqual(reportPayload({ ...valid(), behaviors: ['asustado', 'agresivo'] }, position, null).behaviors, ['asustado', 'agresivo'])
})

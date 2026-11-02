import assert from 'node:assert/strict'
import test from 'node:test'
import { errorSummary, firstErrorField, reportCondition, reportFields, reportPayload, reportSummary, toggleOption, validateReport } from '../src/services/reportForm.ts'

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
test('permite varios estados, también "Bien" junto a otros', () => {
  assert.deepEqual(toggleOption(['bien'], 'prenada'), ['bien', 'prenada'])
  assert.deepEqual(validateReport({ ...valid(), conditions: ['bien', 'prenada', 'parasitos'] }, position), {})
  assert.ok(validateReport({ ...valid(), conditions: ['volando'] }, position).conditions)
})
test('acepta el peso escrito con kg', () => {
  assert.deepEqual(validateReport({ ...valid(), weight_kg: '12 kg' }, position), {})
  assert.equal(reportPayload({ ...valid(), weight_kg: '3,5kg' }, position, null).weight_kg, 3.5)
})
test('el mensaje dice qué campos revisar, en el orden del formulario', () => {
  const errors = validateReport({ ...valid(), color: '', description: 'corto' }, position)
  assert.equal(errorSummary(errors), 'Revisa: Color y Comentarios.')
  assert.equal(firstErrorField(errors), 'color')
  assert.equal(errorSummary(validateReport({ ...valid(), size: '' }, position)), 'Revisa: Tamaño.')
  assert.equal(errorSummary(validateReport(reportFields(), null)), 'Revisa: Ubicación, Tipo de animal, Tamaño, Color, Estado y Comentarios.')
})
test('permite varios comportamientos o ninguno', () => {
  assert.deepEqual(toggleOption([], 'asustado'), ['asustado'])
  assert.deepEqual(toggleOption(['asustado'], 'agresivo'), ['asustado', 'agresivo'])
  assert.deepEqual(toggleOption(['asustado', 'agresivo'], 'asustado'), ['agresivo'])
  assert.deepEqual(reportPayload({ ...valid(), behaviors: ['asustado', 'agresivo'] }, position, null).behaviors, ['asustado', 'agresivo'])
})

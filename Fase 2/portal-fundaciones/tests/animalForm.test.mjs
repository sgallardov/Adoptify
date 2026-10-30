import assert from 'node:assert/strict'
import test from 'node:test'
import { animalFields, animalPayload, animalValidationErrors, validateAnimal } from '../src/services/animalForm.ts'

const valid = () => ({ ...animalFields(), name: ' Luna ', species: 'gato', gender: 'hembra', size: 'pequeño' })

test('rechaza obligatorios vacíos o compuestos por espacios', () => {
  const errors = validateAnimal({ ...animalFields(), name: '   ' }, false, false)
  assert.deepEqual(Object.keys(errors).sort(), ['gender', 'name', 'size', 'species'])
  assert.match(errors.name, /nombre/)
})
test('normaliza los datos sin enviar una fundación para cuentas de fundación', () => {
  const fields = { ...valid(), age_months: '0', foundation_id: '99' }
  assert.deepEqual(validateAnimal(fields, false, false), {})
  const payload = animalPayload(fields, false, 'available')
  assert.equal(payload.name, 'Luna')
  assert.equal(payload.age_months, 0)
  assert.equal(payload.description, null)
  assert.ok(!Object.hasOwn(payload, 'foundation_id'))
  assert.ok(!Object.hasOwn(payload, 'latitude'))
})
test('envía coordenadas numéricas juntas, sin invertir latitud y longitud', () => {
  const fields = { ...valid(), latitude: '-33.4489', longitude: '-70.6693' }
  assert.deepEqual(validateAnimal(fields, false, true), {})
  const payload = animalPayload(fields, false, 'in_process')
  assert.equal(payload.latitude, -33.4489)
  assert.equal(payload.longitude, -70.6693)
})
test('impide coordenadas parciales, fuera de rango y borrar ubicación existente', () => {
  assert.ok(validateAnimal({ ...valid(), latitude: '-33' }, false, false).longitude)
  assert.ok(validateAnimal({ ...valid(), latitude: '91', longitude: '-181' }, false, false).latitude)
  assert.ok(validateAnimal(valid(), false, true).latitude)
})
test('valida edad, energía, largos de texto y protocolo de foto', () => {
  const errors = validateAnimal({ ...valid(), age_months: '1.5', energy_level: '6', breed: 'a'.repeat(101), description: 'a'.repeat(2001), photo_url: 'javascript:alert(1)' }, false, false)
  assert.deepEqual(Object.keys(errors).sort(), ['age_months', 'breed', 'description', 'energy_level', 'photo_url'])
})
test('administrador debe indicar una fundación existente por ID positivo', () => {
  assert.ok(validateAnimal(valid(), true, false).foundation_id)
  const fields = { ...valid(), foundation_id: '12' }
  assert.deepEqual(validateAnimal(fields, true, false), {})
  assert.equal(animalPayload(fields, true, 'available').foundation_id, 12)
})
test('edición conserva valores vacíos y coordenadas del backend sin usar los textos de presentación', () => {
  const fields = animalFields({ ...animalPayload(valid(), false, 'adopted'), id: 1, foundation_id: 2, foundation_name: 'Prueba', latitude: 0, longitude: 0 })
  assert.equal(fields.age_months, '')
  assert.equal(fields.description, '')
  assert.equal(fields.latitude, '0')
  assert.equal(fields.longitude, '0')
})
test('traduce errores 422 sin mostrar mensajes Pydantic en inglés', () => {
  const errors = animalValidationErrors([{ loc: ['body', 'size'], msg: 'Input should be ...' }, { loc: ['body', 'unknown'], msg: 'secret' }])
  assert.equal(errors.size, 'Selecciona pequeño, mediano o grande.')
  assert.equal(Object.keys(errors).length, 1)
  assert.deepEqual(animalValidationErrors('Error'), {})
})

import assert from 'node:assert/strict'
import test from 'node:test'
import { emptyMember, memberPayload, validateMember } from '../src/services/memberForm.ts'

const valid = () => ({ ...emptyMember('2026-03-15'), name: ' Ana Pérez ' })

test('un socio con nombre y fecha es válido sin aporte', () => {
  assert.deepEqual(validateMember(valid()), {})
})
test('exige nombre y fecha', () => {
  const errors = validateMember({ ...valid(), name: '   ', joined_at: '' })
  assert.deepEqual(Object.keys(errors).sort(), ['joined_at', 'name'])
})
test('valida el formato del aporte', () => {
  assert.match(validateMember({ ...valid(), contribution: '-5' }).contribution, /monto/)
  assert.match(validateMember({ ...valid(), contribution: '12.345' }).contribution, /monto/)
  assert.deepEqual(validateMember({ ...valid(), contribution: '15000,50' }), {})
})
test('el payload recorta el nombre, normaliza el aporte y no marca público por defecto', () => {
  assert.deepEqual(memberPayload({ ...valid(), contribution: '15000,50' }),
    { name: 'Ana Pérez', contribution: '15000.50', joined_at: '2026-03-15', is_public: false })
  assert.equal(memberPayload(valid()).contribution, null)
})

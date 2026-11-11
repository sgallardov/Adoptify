import assert from 'node:assert/strict'
import test from 'node:test'
import { cleanCode, isCompleteCode, mustRestart } from '../src/services/verificationCode.ts'

test('el código queda en 6 dígitos aunque se pegue con texto o espacios', () => {
  assert.equal(cleanCode('123 456'), '123456')
  assert.equal(cleanCode('Código: 9876543'), '987654')
  assert.equal(cleanCode('abc'), '')
})
test('solo 6 dígitos son un código completo', () => {
  assert.equal(isCompleteCode('123456'), true)
  assert.equal(isCompleteCode('12345'), false)
  assert.equal(isCompleteCode('12345a'), false)
})
test('un código incorrecto con intentos deja seguir; vencido o agotado vuelve a la contraseña', () => {
  assert.equal(mustRestart(401, 'El código no es correcto. Te quedan 4 intentos.'), false)
  assert.equal(mustRestart(401, 'El código venció. Inicia sesión otra vez para recibir un código nuevo.'), true)
  assert.equal(mustRestart(401, 'Demasiados intentos con un código incorrecto. Inicia sesión otra vez.'), true)
  assert.equal(mustRestart(429, 'Espera 30 segundos para pedir otro código.'), false)
  assert.equal(mustRestart(undefined, undefined), false)
})

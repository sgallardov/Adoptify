import assert from 'node:assert/strict'
import test from 'node:test'
import { matchCommune } from '../src/services/communeMatch.ts'

const communes = ['Aysén', 'Ñuñoa', "O'Higgins", 'Santiago']

test('reconoce la comuna aunque se escriba sin tildes ni mayúsculas', () => {
  assert.equal(matchCommune('aysen', communes), 'Aysén')
  assert.equal(matchCommune('  NUNOA ', communes), 'Ñuñoa')
  assert.equal(matchCommune('o higgins', communes), "O'Higgins")
})

test('un texto que no es comuna no se acepta', () => {
  assert.equal(matchCommune('Mi casa', communes), null)
  assert.equal(matchCommune('', communes), null)
})

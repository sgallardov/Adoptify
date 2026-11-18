import assert from 'node:assert/strict'
import test from 'node:test'
import { emptyQuestion, formatAnswer, questionsPayload, toDraft, validateQuestions } from '../src/services/adoptionFormEditor.ts'

const draft = (overrides) => ({ ...emptyQuestion(), label: '¿Tienes patio?', ...overrides })

test('una pregunta de texto con enunciado es válida', () => {
  assert.deepEqual(validateQuestions([draft()]), {})
})
test('exige enunciado y al menos 2 alternativas distintas', () => {
  const errors = validateQuestions([
    draft({ label: '   ' }),
    draft({ kind: 'choice', optionsText: 'Casa\n\n' }),
    draft({ kind: 'choice', optionsText: 'Casa\ncasa' }),
    draft({ kind: 'choice', optionsText: 'Casa\nDepartamento' }),
  ])
  assert.deepEqual(Object.keys(errors), ['0', '1', '2'])
  assert.match(errors[1], /2 alternativas/)
  assert.match(errors[2], /repetirse/)
})
test('el payload recorta textos y solo manda alternativas en preguntas de alternativas', () => {
  assert.deepEqual(questionsPayload([
    draft({ label: '  ¿Vivienda? ', kind: 'choice', optionsText: ' Casa \nDepartamento\n' }),
    draft({ kind: 'yes_no', optionsText: 'quedó de antes', required: false }),
  ]), [
    { label: '¿Vivienda?', kind: 'choice', options: ['Casa', 'Departamento'], required: true },
    { label: '¿Tienes patio?', kind: 'yes_no', options: [], required: false },
  ])
})
test('toDraft deja las alternativas una por línea', () => {
  assert.equal(toDraft({ label: 'x', kind: 'choice', options: ['A', 'B'], required: true }).optionsText, 'A\nB')
})
test('formatea las respuestas para la fundación', () => {
  assert.equal(formatAnswer(true), 'Sí')
  assert.equal(formatAnswer(false), 'No')
  assert.equal(formatAnswer(null), 'Sin respuesta')
  assert.equal(formatAnswer('Casa'), 'Casa')
})

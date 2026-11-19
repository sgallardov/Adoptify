import assert from 'node:assert/strict'
import test from 'node:test'
import {
  defaultDecisionMessage, emptyQuestion, flaggedOf, formatAnswer, questionnaireStatus, questionsPayload, toDraft, validateQuestions,
} from '../src/services/adoptionFormEditor.ts'

const draft = (overrides) => ({ ...emptyQuestion(), label: '¿Tienes patio?', ...overrides })

test('una pregunta de texto con enunciado es válida', () => {
  assert.deepEqual(validateQuestions([draft()]), {})
})

test('exige enunciado, al menos 2 alternativas distintas y que una cumpla', () => {
  const errors = validateQuestions([
    draft({ label: '   ' }),
    draft({ kind: 'choice', optionsText: 'Casa\n\n' }),
    draft({ kind: 'choice', optionsText: 'Casa\ncasa' }),
    draft({ kind: 'choice', optionsText: 'Casa\nDepartamento', flagged: ['Casa', 'Departamento'] }),
    draft({ kind: 'choice', optionsText: 'Casa\nDepartamento', flagged: ['Departamento'] }),
  ])
  assert.deepEqual(Object.keys(errors), ['0', '1', '2', '3'])
  assert.match(errors[1], /2 alternativas/)
  assert.match(errors[2], /repetirse/)
  assert.match(errors[3], /debe cumplir/)
})

test('el payload recorta textos y manda lo que no cumple solo si sigue siendo una respuesta posible', () => {
  assert.deepEqual(questionsPayload([
    draft({ label: '  ¿Vivienda? ', kind: 'choice', optionsText: ' Casa \nDepartamento\n', flagged: ['Departamento', 'Parcela'] }),
    draft({ kind: 'yes_no', optionsText: 'quedó de antes', required: false, flagged: [false] }),
    draft({ kind: 'text', flagged: [false] }),
  ]), [
    { label: '¿Vivienda?', kind: 'choice', options: ['Casa', 'Departamento'], required: true, flagged_answers: ['Departamento'] },
    { label: '¿Tienes patio?', kind: 'yes_no', options: [], required: false, flagged_answers: [false] },
    { label: '¿Tienes patio?', kind: 'text', options: [], required: true, flagged_answers: [] },
  ])
})

test('una de sí o no marca a lo más una respuesta', () => {
  assert.deepEqual(flaggedOf(draft({ kind: 'yes_no', flagged: [false, true, 'No'] })), [false])
})

test('toDraft deja las alternativas una por línea y conserva lo que no cumple', () => {
  const result = toDraft({ label: 'x', kind: 'choice', options: ['A', 'B'], required: true, flagged_answers: ['B'] })
  assert.equal(result.optionsText, 'A\nB')
  assert.deepEqual(result.flagged, ['B'])
})

test('formatea las respuestas para la fundación', () => {
  assert.equal(formatAnswer(true), 'Sí')
  assert.equal(formatAnswer(false), 'No')
  assert.equal(formatAnswer(null), 'Prefiero no responder')
  assert.equal(formatAnswer('Casa'), 'Casa')
})

test('los mensajes predeterminados nombran a la persona y a la mascota', () => {
  const accepted = defaultDecisionMessage('accepted', 'Luna', 'Matías')
  const rejected = defaultDecisionMessage('rejected', 'Luna', 'Matías')
  assert.match(accepted, /^¡Buenas noticias, Matías!/)
  assert.match(accepted, /adopción de Luna/)
  assert.match(rejected, /Gracias por tu interés en Luna, Matías/)
  assert.match(rejected, /no podemos continuar/)
})

test('el estado junto al interesado muestra el avance o el resultado', () => {
  const base = { id: 1, answered: 8, total: 8, completed: true, flagged: 0, decision: null }
  assert.deepEqual(questionnaireStatus({ ...base, answered: 3, completed: false }), { text: 'Respondiendo 3 de 8', tone: 'neutral' })
  assert.deepEqual(questionnaireStatus(base), { text: 'Cumple todo', tone: 'success' })
  assert.deepEqual(questionnaireStatus({ ...base, flagged: 2 }), { text: '2 respuestas no cumplen', tone: 'danger' })
  assert.equal(questionnaireStatus({ ...base, flagged: 1 }).text, '1 respuesta no cumple')
  assert.equal(questionnaireStatus({ ...base, decision: 'accepted' }).text, 'Aceptada')
  assert.equal(questionnaireStatus({ ...base, decision: 'rejected' }).text, 'Rechazada')
})

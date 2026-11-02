import assert from 'node:assert/strict'
import test from 'node:test'
import { photoError, resolveMediaUrl } from '../src/services/photo.ts'

test('acepta JPG y PNG de hasta 5 MB', () => {
  assert.equal(photoError({ type: 'image/jpeg', size: 1024 }), null)
  assert.equal(photoError({ type: 'image/png', size: 5 * 1024 * 1024 }), null)
})
test('rechaza otros formatos y archivos de más de 5 MB', () => {
  assert.match(photoError({ type: 'application/pdf', size: 1024 }), /JPG o PNG/)
  assert.match(photoError({ type: 'image/gif', size: 1024 }), /JPG o PNG/)
  assert.match(photoError({ type: 'image/jpeg', size: 5 * 1024 * 1024 + 1 }), /5 MB/)
})
test('las fotos subidas se piden al servidor de la API aunque se hayan subido desde el emulador', () => {
  assert.equal(resolveMediaUrl('http://10.0.2.2:8000/uploads/abc.jpg', 'http://localhost:8000/api/v1'), 'http://localhost:8000/uploads/abc.jpg')
})
test('las fotos externas, los vacíos y los textos inválidos no cambian', () => {
  const external = 'https://images.unsplash.com/photo-1543466835?w=900'
  assert.equal(resolveMediaUrl(external, 'http://localhost:8000/api/v1'), external)
  assert.equal(resolveMediaUrl(null, 'http://localhost:8000/api/v1'), null)
  assert.equal(resolveMediaUrl('no es url', 'http://localhost:8000/api/v1'), 'no es url')
})

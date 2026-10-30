import type { AnimalInput, AnimalResponse } from './animals'

export type AnimalFields = {
  name: string; species: string; gender: string; size: string; breed: string
  age_months: string; energy_level: string; description: string; photo_url: string
  latitude: string; longitude: string; foundation_id: string
}
export type FieldErrors = Partial<Record<keyof AnimalFields | 'status', string>>

export function animalFields(animal?: AnimalResponse): AnimalFields {
  return {
    name: animal?.name ?? '', species: animal?.species ?? '', gender: animal?.gender ?? '',
    size: animal?.size ?? '', breed: animal?.breed ?? '', age_months: animal?.age_months?.toString() ?? '',
    energy_level: String(animal?.energy_level ?? 3), description: animal?.description ?? '',
    photo_url: animal?.photo_url ?? '', latitude: animal?.latitude?.toString() ?? '',
    longitude: animal?.longitude?.toString() ?? '', foundation_id: '',
  }
}

export function validateAnimal(fields: AnimalFields, adminCreate: boolean, hadLocation: boolean): FieldErrors {
  const errors: FieldErrors = {}
  if (!fields.name.trim()) errors.name = 'Escribe el nombre del animal.'
  else if (fields.name.trim().length > 100) errors.name = 'El nombre admite hasta 100 caracteres.'
  if (!['perro', 'gato'].includes(fields.species)) errors.species = 'Selecciona una especie: perro o gato.'
  if (!['pequeño', 'mediano', 'grande'].includes(fields.size)) errors.size = 'Selecciona el tamaño del animal.'
  if (!['macho', 'hembra'].includes(fields.gender)) errors.gender = 'Selecciona el sexo del animal.'
  if (fields.breed.length > 100) errors.breed = 'La raza admite hasta 100 caracteres.'
  if (fields.age_months.trim() && (!Number.isInteger(Number(fields.age_months)) || Number(fields.age_months) < 0 || Number(fields.age_months) > 360)) errors.age_months = 'Indica una edad entera entre 0 y 360 meses.'
  if (!Number.isInteger(Number(fields.energy_level)) || Number(fields.energy_level) < 1 || Number(fields.energy_level) > 5) errors.energy_level = 'Selecciona una energía entre 1 y 5.'
  if (fields.description.length > 2000) errors.description = 'La descripción admite hasta 2000 caracteres.'
  if (fields.photo_url.trim()) {
    try {
      const url = new URL(fields.photo_url.trim())
      if (!['http:', 'https:'].includes(url.protocol) || fields.photo_url.trim().length > 500) throw new Error()
    } catch { errors.photo_url = 'Ingresa un enlace de foto válido que comience con https:// o http:// (máximo 500 caracteres).' }
  }
  const latitude = fields.latitude.trim(), longitude = fields.longitude.trim()
  if (latitude || longitude || hadLocation) {
    if (!latitude || !Number.isFinite(Number(latitude)) || Math.abs(Number(latitude)) > 90) errors.latitude = 'Indica una latitud válida entre -90 y 90 o elige un punto en el mapa.'
    if (!longitude || !Number.isFinite(Number(longitude)) || Math.abs(Number(longitude)) > 180) errors.longitude = 'Indica una longitud válida entre -180 y 180 o elige un punto en el mapa.'
  }
  if (adminCreate && (!fields.foundation_id.trim() || !Number.isSafeInteger(Number(fields.foundation_id)) || Number(fields.foundation_id) < 1)) errors.foundation_id = 'Indica el ID de una fundación existente.'
  return errors
}

export function animalPayload(fields: AnimalFields, adminCreate: boolean, status: AnimalInput['status']): AnimalInput {
  return {
    name: fields.name.trim(), species: fields.species, gender: fields.gender, size: fields.size,
    breed: fields.breed.trim() || null, age_months: fields.age_months.trim() ? Number(fields.age_months) : null,
    energy_level: Number(fields.energy_level), description: fields.description.trim() || null,
    photo_url: fields.photo_url.trim() || null, status,
    ...(fields.latitude.trim() && fields.longitude.trim() ? { latitude: Number(fields.latitude), longitude: Number(fields.longitude) } : {}),
    ...(adminCreate ? { foundation_id: Number(fields.foundation_id) } : {}),
  }
}

const fieldMessages: Record<string, string> = {
  name: 'Escribe un nombre de 1 a 100 caracteres.', species: 'Selecciona perro o gato.',
  gender: 'Selecciona macho o hembra.', size: 'Selecciona pequeño, mediano o grande.',
  breed: 'La raza admite hasta 100 caracteres.', age_months: 'Indica una edad entera entre 0 y 360 meses.',
  energy_level: 'La energía debe estar entre 1 y 5.', description: 'La descripción admite hasta 2000 caracteres.',
  photo_url: 'Revisa el enlace de la foto (máximo 500 caracteres).', latitude: 'Revisa la latitud y la longitud.',
  longitude: 'Revisa la latitud y la longitud.', foundation_id: 'Revisa la fundación asignada.',
  status: 'Selecciona Disponible, En proceso o Adoptado.',
}

// Traduce la estructura 422 de Pydantic sin exponer mensajes internos en inglés.
export function animalValidationErrors(detail: unknown): FieldErrors {
  const errors: FieldErrors = {}
  if (!Array.isArray(detail)) return errors
  for (const item of detail) {
    const field = Array.isArray(item?.loc) ? item.loc.at(-1) : null
    if (typeof field === 'string' && Object.hasOwn(fieldMessages, field)) errors[field as keyof FieldErrors] = fieldMessages[field]
  }
  return errors
}

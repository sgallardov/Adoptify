import type { LatLng } from '../hooks/useMapAnimals'
import type { DogReport, ReportInput } from './reports'

export const MIN_COMMENT = 10
export const MAX_COMMENT = 1000

// Opciones del formulario: [valor que guarda la API, texto que ve el usuario]
export const reportOptions = {
  species: [['perro', 'Perro'], ['gato', 'Gato'], ['otro', 'Otro']],
  size: [['pequeño', 'Pequeño'], ['mediano', 'Mediano'], ['grande', 'Grande']],
  condition: [['bien', 'Bien'], ['desnutrido', 'Desnutrido'], ['herido', 'Herido'], ['enfermo', 'Enfermo'], ['deplorable', 'Deplorable']],
  behavior: [['tranquilo', 'Tranquilo'], ['asustado', 'Asustado'], ['agresivo', 'Agresivo']],
} as const satisfies Record<string, readonly (readonly [string, string])[]>

export function reportLabel(field: keyof typeof reportOptions, value: string | null | undefined): string | null {
  if (!value) return null
  return reportOptions[field].find(([option]) => option === value)?.[1] ?? value
}

export type ReportFields = {
  species: string; size: string; weight_kg: string; color: string
  features: string; conditions: string[]; behaviors: string[]; description: string
}
// Campos que admiten varias opciones
export type MultiField = 'conditions' | 'behaviors'
export type TextField = Exclude<keyof ReportFields, MultiField>
export type ReportErrors = Partial<Record<keyof ReportFields | 'position', string>>

export function reportFields(): ReportFields {
  return { species: '', size: '', weight_kg: '', color: '', features: '', conditions: [], behaviors: [], description: '' }
}

// Marca o desmarca un estado. "Bien" no se combina con los demás: elegirlo deja solo "Bien" y elegir otro lo quita.
export function toggleCondition(current: string[], value: string): string[] {
  if (current.includes(value)) return current.filter(item => item !== value)
  return value === 'bien' ? ['bien'] : [...current.filter(item => item !== 'bien'), value]
}

export function toggleOption(current: string[], value: string): string[] {
  return current.includes(value) ? current.filter(item => item !== value) : [...current, value]
}

const allowed = (field: keyof typeof reportOptions, value: string) => reportOptions[field].some(([option]) => option === value)

export function validateReport(fields: ReportFields, position: LatLng | null): ReportErrors {
  const errors: ReportErrors = {}
  if (!position) errors.position = 'Marca en el mapa dónde está la mascota.'
  if (!allowed('species', fields.species)) errors.species = 'Selecciona el tipo de animal.'
  if (!allowed('size', fields.size)) errors.size = 'Selecciona el tamaño.'
  const weight = fields.weight_kg.trim().replace(',', '.')
  if (weight && (!Number.isFinite(Number(weight)) || Number(weight) <= 0 || Number(weight) > 150)) errors.weight_kg = 'Indica un peso aproximado entre 0 y 150 kg.'
  if (fields.color.trim().length < 2) errors.color = 'Indica el color (por ejemplo, café o negro con blanco).'
  if (fields.features.length > 300) errors.features = 'Las características admiten hasta 300 caracteres.'
  if (!fields.conditions.length || !fields.conditions.every(value => allowed('condition', value))) errors.conditions = 'Selecciona cómo se encuentra (una o más opciones).'
  else if (fields.conditions.includes('bien') && fields.conditions.length > 1) errors.conditions = '"Bien" no se puede combinar con otros estados.'
  if (!fields.behaviors.every(value => allowed('behavior', value))) errors.behaviors = 'Selecciona comportamientos de la lista.'
  if (fields.description.trim().length < MIN_COMMENT) errors.description = `Cuéntanos la situación con al menos ${MIN_COMMENT} caracteres.`
  return errors
}

export function reportPayload(fields: ReportFields, position: LatLng, photoUrl: string | null): ReportInput {
  const weight = fields.weight_kg.trim().replace(',', '.')
  return {
    latitude: position.lat, longitude: position.lng,
    species: fields.species, size: fields.size, color: fields.color.trim(), conditions: fields.conditions,
    weight_kg: weight ? Number(weight) : null, features: fields.features.trim() || null,
    behaviors: fields.behaviors, description: fields.description.trim(),
    ...(photoUrl ? { photo_url: photoUrl } : {}),
  }
}

type ReportDetails = Pick<DogReport, 'species' | 'size' | 'weight_kg' | 'color' | 'conditions' | 'behaviors'>

// Resumen legible de la ficha para el mapa: "Perro · Mediano · Café · ~12 kg". Vacío en reportes antiguos.
export function reportSummary(report: ReportDetails): string {
  return [
    reportLabel('species', report.species), reportLabel('size', report.size), report.color,
    report.weight_kg != null ? `~${report.weight_kg.toLocaleString('es-CL')} kg` : null,
  ].filter(Boolean).join(' · ')
}

// Estados y comportamientos: "Herido, Desnutrido · Asustado"
export function reportCondition(report: ReportDetails): string {
  const conditions = report.conditions.map(value => reportLabel('condition', value)).join(', ')
  const behaviors = report.behaviors.map(value => reportLabel('behavior', value)).join(', ')
  return [conditions, behaviors].filter(Boolean).join(' · ')
}

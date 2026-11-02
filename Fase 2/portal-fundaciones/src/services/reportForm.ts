import type { LatLng } from '../hooks/useMapAnimals'
import type { DogReport, ReportInput } from './reports'

export const MIN_COMMENT = 10
export const MAX_COMMENT = 1000

// Opciones del formulario: [valor que guarda la API, texto que ve el usuario]
export const reportOptions = {
  species: [['perro', 'Perro'], ['gato', 'Gato'], ['otro', 'Otro']],
  size: [['pequeño', 'Pequeño'], ['mediano', 'Mediano'], ['grande', 'Grande']],
  // Estado y comportamiento admiten varias opciones (mismas que el backend y la app)
  condition: [
    ['bien', 'Bien'], ['desnutrido', 'Desnutrido'], ['deshidratado', 'Deshidratado'], ['herido', 'Herido'], ['sangrando', 'Sangrando'],
    ['cojea', 'Cojea'], ['atropellado', 'Atropellado'], ['no_se_mueve', 'No se puede mover'], ['enfermo', 'Enfermo'], ['problemas_piel', 'Sarna o problemas de piel'],
    ['parasitos', 'Pulgas o garrapatas'], ['problemas_ojos', 'Problemas en los ojos'], ['prenada', 'Preñada'], ['con_crias', 'Con crías'], ['deplorable', 'Deplorable'],
  ],
  behavior: [
    ['tranquilo', 'Tranquilo'], ['amistoso', 'Amistoso, se deja tocar'], ['jugueton', 'Juguetón'], ['sigue_personas', 'Sigue a las personas'], ['decaido', 'Decaído'],
    ['asustado', 'Asustado'], ['se_esconde', 'Se esconde'], ['huye', 'Huye al acercarse'], ['nervioso', 'Nervioso'],
    ['desconfiado', 'Desconfiado'], ['ruidoso', 'Ladra o maúlla mucho'], ['protector', 'Protege a sus crías'], ['agresivo', 'Agresivo'],
  ],
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

// Nombre de cada campo en el orden del formulario, para decir cuáles hay que revisar
export const fieldLabels: Record<keyof ReportErrors, string> = {
  position: 'Ubicación', species: 'Tipo de animal', size: 'Tamaño', color: 'Color', weight_kg: 'Peso aproximado',
  features: 'Características', conditions: 'Estado', behaviors: 'Comportamiento', description: 'Comentarios',
}

// "Revisa: Color y Comentarios." Los campos van en el orden en que aparecen en el formulario.
export function errorSummary(errors: ReportErrors): string {
  const names = (Object.keys(fieldLabels) as (keyof ReportErrors)[]).filter(field => errors[field]).map(field => fieldLabels[field])
  if (!names.length) return ''
  const list = names.length === 1 ? names[0] : `${names.slice(0, -1).join(', ')} y ${names.at(-1)}`
  return `Revisa: ${list}.`
}

// Primer campo con error, para llevar a la persona hasta él
export function firstErrorField(errors: ReportErrors): keyof ReportErrors | undefined {
  return (Object.keys(fieldLabels) as (keyof ReportErrors)[]).find(field => errors[field])
}

// Acepta "12", "12,5", "12 kg" o "12kg"
function weightText(value: string): string {
  return value.trim().toLowerCase().replace(/\s*kg$/, '').replace(',', '.')
}

export function reportFields(): ReportFields {
  return { species: '', size: '', weight_kg: '', color: '', features: '', conditions: [], behaviors: [], description: '' }
}

// Marca o desmarca una opción de estado o comportamiento
export function toggleOption(current: string[], value: string): string[] {
  return current.includes(value) ? current.filter(item => item !== value) : [...current, value]
}

const allowed = (field: keyof typeof reportOptions, value: string) => reportOptions[field].some(([option]) => option === value)

export function validateReport(fields: ReportFields, position: LatLng | null): ReportErrors {
  const errors: ReportErrors = {}
  if (!position) errors.position = 'Marca en el mapa dónde está la mascota.'
  if (!allowed('species', fields.species)) errors.species = 'Selecciona el tipo de animal.'
  if (!allowed('size', fields.size)) errors.size = 'Selecciona el tamaño.'
  const weight = weightText(fields.weight_kg)
  if (weight && (!Number.isFinite(Number(weight)) || Number(weight) <= 0 || Number(weight) > 150)) errors.weight_kg = 'Indica un peso aproximado entre 0 y 150 kg.'
  if (fields.color.trim().length < 2) errors.color = 'Indica el color (por ejemplo, café o negro con blanco).'
  if (fields.features.length > 300) errors.features = 'Las características admiten hasta 300 caracteres.'
  if (!fields.conditions.length || !fields.conditions.every(value => allowed('condition', value))) errors.conditions = 'Selecciona cómo se encuentra (una o más opciones).'
  if (!fields.behaviors.every(value => allowed('behavior', value))) errors.behaviors = 'Selecciona comportamientos de la lista.'
  if (fields.description.trim().length < MIN_COMMENT) errors.description = `Cuéntanos la situación con al menos ${MIN_COMMENT} caracteres.`
  return errors
}

export function reportPayload(fields: ReportFields, position: LatLng, photoUrl: string | null): ReportInput {
  const weight = weightText(fields.weight_kg)
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

import type { FosterApplication, FosterStatus } from './fosterApplications'

// Textos de las postulaciones a hogar temporal (HU-B), sin depender de React

export const statusLabels: Record<FosterStatus, string> = {
  pending: 'Pendiente',
  approved: 'Aprobada',
  rejected: 'No aprobada',
}

const speciesLabels: Record<FosterApplication['species'], string> = { perro: 'Perros', gato: 'Gatos', ambos: 'Perros y gatos' }
const spaceLabels: Record<FosterApplication['space'], string> = {
  casa_patio: 'Casa con patio',
  casa_sin_patio: 'Casa sin patio',
  departamento: 'Departamento',
}
const sizeOrder = ['pequeño', 'mediano', 'grande']

export const speciesLabel = (species: FosterApplication['species']): string => speciesLabels[species] ?? species
export const spaceLabel = (space: FosterApplication['space']): string => spaceLabels[space] ?? space

// "Pequeño y grande", "Pequeño, mediano y grande"
export function sizesLabel(sizes: string[]): string {
  const sorted = [...sizes].sort((a, b) => sizeOrder.indexOf(a) - sizeOrder.indexOf(b))
  const text = sorted.length <= 1 ? sorted.join('') : `${sorted.slice(0, -1).join(', ')} y ${sorted[sorted.length - 1]}`
  return text.charAt(0).toUpperCase() + text.slice(1)
}

// "Hasta 2 animales a la vez · máx. 30 días"
export function capacityLabel(application: Pick<FosterApplication, 'max_animals' | 'max_days'>): string {
  const animals = application.max_animals === 1 ? '1 animal' : `${application.max_animals} animales`
  const days = application.max_days === 1 ? '1 día' : `${application.max_days} días`
  return `Hasta ${animals} a la vez · máx. ${days}`
}

// Teléfono para enlaces tel: solo + y dígitos
export const phoneHref = (phone: string): string => `tel:${phone.replace(/[^\d+]/g, '')}`

import type { Animal, AnimalStatus } from '../data/demo'

/** Etiquetas en español de cada estado de adopción. */
export const statuses: Record<AnimalStatus, string> = {
  available: 'Disponible', in_process: 'En proceso', adopted: 'Adoptado', follow_up: 'Seguimiento',
}

/** Título de cada pestaña: en plural, a diferencia de la etiqueta de un animal. Igual que en la app. */
export const tabLabels: Record<AnimalStatus, string> = {
  available: 'Disponibles', in_process: 'En proceso', adopted: 'Adoptados', follow_up: 'Seguimiento',
}

// Orden de la gestión: primero los que buscan hogar, al final el seguimiento posterior a la adopción (HU-Y)
export const statusTabs: AnimalStatus[] = ['available', 'in_process', 'adopted', 'follow_up']

export const tabId = (status: AnimalStatus) => `pestana-${status}`
export const panelId = (status: AnimalStatus) => `panel-${status}`

/** Estado de un animal; los datos de maqueta sin estado del backend se tratan como disponibles. */
export function statusOf(animal: Animal): AnimalStatus {
  return animal.statusKey ?? 'available'
}

/** Cada animal cuenta en una sola pestaña: la de su estado actual. */
export function countByStatus(animals: Animal[]): Record<AnimalStatus, number> {
  const counts = Object.fromEntries(statusTabs.map(status => [status, 0])) as Record<AnimalStatus, number>
  for (const animal of animals) counts[statusOf(animal)] += 1
  return counts
}

export function inStatus(animals: Animal[], status: AnimalStatus): Animal[] {
  return animals.filter(animal => statusOf(animal) === status)
}

/** Seguimiento es la etapa posterior a la adopción: solo se ofrece a un animal adoptado o ya en seguimiento. */
export function statusOptions(current?: AnimalStatus): AnimalStatus[] {
  return current === 'adopted' || current === 'follow_up'
    ? statusTabs
    : statusTabs.filter(status => status !== 'follow_up')
}

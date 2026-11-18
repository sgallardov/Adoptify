// Igual que find_commune del backend: sin tildes, eñes, apóstrofos ni mayúsculas
export function foldCommune(text: string): string {
  return text.normalize('NFD').replace(/\p{Mn}/gu, '').replace(/'/g, ' ').toLocaleLowerCase('es').split(/\s+/).filter(Boolean).join(' ')
}

// Nombre del catálogo que corresponde a lo escrito ("aysen" -> "Aysén"), o null
export function matchCommune(text: string, communes: string[]): string | null {
  const folded = foldCommune(text)
  if (!folded) return null
  return communes.find(name => foldCommune(name) === folded) ?? null
}

export const MAX_PHOTO_MB = 5
const PHOTO_TYPES = ['image/jpeg', 'image/png']

// Revisión rápida antes de subir; el backend vuelve a validar por el contenido del archivo
export function photoError(file: { type: string; size: number }): string | null {
  if (!PHOTO_TYPES.includes(file.type)) return 'El archivo no es una imagen válida. Usa JPG o PNG.'
  if (file.size > MAX_PHOTO_MB * 1024 * 1024) return `La imagen es muy pesada. El máximo es ${MAX_PHOTO_MB} MB.`
  return null
}

// Las fotos subidas (/uploads/...) se piden al mismo servidor que la API. El backend arma la URL con la
// dirección desde la que se subió: una foto subida desde el emulador (10.0.2.2) no abriría en el navegador.
export function resolveMediaUrl(url: string | null, apiBase: string): string | null {
  if (!url) return null
  try {
    const parsed = new URL(url)
    if (!parsed.pathname.startsWith('/uploads/')) return url
    return new URL(parsed.pathname, apiBase).toString()
  } catch { return url }
}

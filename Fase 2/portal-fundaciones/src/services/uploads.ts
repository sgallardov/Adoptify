import { api } from './api'
import { resolveMediaUrl } from './photo'

// Sube una foto (POST /uploads, multipart) y devuelve su URL para guardarla en photo_url
export async function uploadPhoto(file: File): Promise<string> {
  const form = new FormData()
  form.append('file', file)
  // Una foto tarda más en subir que una petición JSON
  const { data } = await api.post<{ url: string }>('/uploads', form, { timeout: 30000 })
  return data.url
}

export function mediaUrl(url: string | null): string | null {
  return resolveMediaUrl(url, api.defaults.baseURL ?? window.location.origin)
}

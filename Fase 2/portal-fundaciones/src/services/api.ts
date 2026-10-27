import axios from 'axios'

const TOKEN_KEY = 'adoptify_token'

export function getToken(): string | null {
  try { return localStorage.getItem(TOKEN_KEY) } catch { return null }
}

export function setToken(token: string | null) {
  try {
    if (token) localStorage.setItem(TOKEN_KEY, token)
    else localStorage.removeItem(TOKEN_KEY)
  } catch { /* Sin almacenamiento disponible: la sesión dura hasta recargar */ }
}

export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1',
  timeout: 10000,
})

// Adjunta el token de sesión a cada petición
api.interceptors.request.use(config => {
  const token = getToken()
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

export function errorMessage(error: unknown, fallback: string): string {
  if (axios.isAxiosError(error)) {
    if (!error.response) return 'No pudimos conectar con el servidor. Inténtalo nuevamente.'
    const detail = error.response.data?.detail
    if (typeof detail === 'string') return detail
    // Errores de validación (422): Pydantic envía una lista; se muestra el primer motivo propio
    const firstMessage = Array.isArray(detail) ? detail[0]?.msg : undefined
    if (typeof firstMessage === 'string' && firstMessage.startsWith('Value error, ')) return firstMessage.replace('Value error, ', '')
    if (error.response.status === 422) return 'Revisa los datos: el correo debe ser válido y la contraseña tener al menos 8 caracteres.'
  }
  return fallback
}

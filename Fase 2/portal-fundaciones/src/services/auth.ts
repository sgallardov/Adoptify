import { api, setToken } from './api'

export type AccountType = 'user' | 'foundation'

export type User = {
  id: number
  email: string
  rut: string
  full_name: string
  role: string
}

export async function login(email: string, password: string, accountType: AccountType): Promise<void> {
  const { data } = await api.post<{ access_token: string }>('/auth/login', { email, password, account_type: accountType })
  setToken(data.access_token)
}

export async function register(email: string, rut: string, password: string, fullName: string): Promise<void> {
  await api.post('/auth/register', { email, rut, password, full_name: fullName })
}

export async function fetchMe(): Promise<User> {
  const { data } = await api.get<User>('/auth/me')
  return data
}

// Página de inicio según el tipo de cuenta
export function homeFor(user: User): string {
  return user.role === 'adopter' ? '/usuario' : '/'
}

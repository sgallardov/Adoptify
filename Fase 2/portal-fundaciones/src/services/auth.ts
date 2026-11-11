import { api, setToken } from './api'

export type AccountType = 'foundation'

export type User = {
  id: number
  email: string
  rut: string
  full_name: string
  role: string
  two_factor_enabled: boolean
}

// Código enviado al correo (HU-I). Con la verificación en dos pasos activa, el login responde esto (202) sin token
export type CodeChallenge = {
  challenge_id: string
  email_hint: string
  expires_in_minutes: number
  resend_in_seconds: number
}

type TokenResponse = { access_token: string }

// null si la sesión quedó iniciada; el desafío si hay que ingresar el código que llegó al correo
export async function login(email: string, password: string, accountType: AccountType): Promise<CodeChallenge | null> {
  const { data } = await api.post<TokenResponse | CodeChallenge>('/auth/login', { email, password, account_type: accountType })
  if ('challenge_id' in data) return data
  setToken(data.access_token)
  return null
}

export async function verifyCode(challengeId: string, code: string): Promise<void> {
  const { data } = await api.post<TokenResponse>('/auth/verify-code', { challenge_id: challengeId, code })
  setToken(data.access_token)
}

export async function resendCode(challengeId: string): Promise<CodeChallenge> {
  const { data } = await api.post<CodeChallenge>('/auth/resend-code', { challenge_id: challengeId })
  return data
}

export async function fetchMe(): Promise<User> {
  const { data } = await api.get<User>('/auth/me')
  return data
}

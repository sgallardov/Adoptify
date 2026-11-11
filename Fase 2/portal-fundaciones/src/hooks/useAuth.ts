import { createContext, useContext } from 'react'
import type { AccountType, CodeChallenge, User } from '../services/auth'

export type AuthState = {
  user: User | null
  loading: boolean
  // null si la sesión quedó iniciada; el desafío si hay que ingresar el código del correo (HU-I)
  signIn: (email: string, password: string, accountType: AccountType) => Promise<CodeChallenge | null>
  verifyCode: (challengeId: string, code: string) => Promise<void>
  signOut: () => void
}

export const AuthContext = createContext<AuthState | null>(null)

export function useAuth(): AuthState {
  const value = useContext(AuthContext)
  if (!value) throw new Error('useAuth debe usarse dentro de AuthProvider')
  return value
}

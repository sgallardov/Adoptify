import { createContext, useContext } from 'react'
import type { AccountType, User } from '../services/auth'

export type AuthState = {
  user: User | null
  loading: boolean
  signIn: (email: string, password: string, accountType: AccountType) => Promise<User>
  signUp: (email: string, rut: string, password: string, fullName: string) => Promise<User>
  signOut: () => void
}

export const AuthContext = createContext<AuthState | null>(null)

export function useAuth(): AuthState {
  const value = useContext(AuthContext)
  if (!value) throw new Error('useAuth debe usarse dentro de AuthProvider')
  return value
}

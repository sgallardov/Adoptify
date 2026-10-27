import { useCallback, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { AuthContext } from '../hooks/useAuth'
import { getToken, setToken } from '../services/api'
import { fetchMe, login, register } from '../services/auth'
import type { AccountType, User } from '../services/auth'

export default function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(() => getToken() !== null)

  // Si hay un token guardado, recupera la sesión; si ya no es válido, se descarta
  useEffect(() => {
    if (!getToken()) return
    fetchMe()
      .then(setUser)
      .catch(() => setToken(null))
      .finally(() => setLoading(false))
  }, [])

  const signIn = useCallback(async (email: string, password: string, accountType: AccountType) => {
    await login(email, password, accountType)
    const me = await fetchMe()
    setUser(me)
    return me
  }, [])

  const signUp = useCallback(async (email: string, rut: string, password: string, fullName: string) => {
    await register(email, rut, password, fullName)
    return signIn(email, password, 'user')
  }, [signIn])

  const signOut = useCallback(() => {
    setToken(null)
    setUser(null)
  }, [])

  const value = useMemo(() => ({ user, loading, signIn, signUp, signOut }), [user, loading, signIn, signUp, signOut])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

import { useCallback, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { AuthContext } from '../hooks/useAuth'
import { getToken, setToken } from '../services/api'
import { fetchMe, login, verifyCode as sendCode } from '../services/auth'
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
    const challenge = await login(email, password, accountType)
    if (challenge) return challenge
    setUser(await fetchMe())
    return null
  }, [])

  const verifyCode = useCallback(async (challengeId: string, code: string) => {
    await sendCode(challengeId, code)
    setUser(await fetchMe())
  }, [])

  const signOut = useCallback(() => {
    setToken(null)
    setUser(null)
  }, [])

  const value = useMemo(() => ({ user, loading, signIn, verifyCode, signOut }), [user, loading, signIn, verifyCode, signOut])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

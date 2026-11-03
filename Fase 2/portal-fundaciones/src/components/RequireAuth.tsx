import { useEffect } from 'react'
import { Navigate, Outlet } from 'react-router'
import Brand from './Brand'
import Feedback from './Feedback'
import { useAuth } from '../hooks/useAuth'

// Deja pasar solo a usuarios con sesión y un rol permitido; al resto los redirige
export default function RequireAuth({ roles }: { roles: string[] }) {
  const { user, loading, signOut } = useAuth()
  const forbidden = !!user && !roles.includes(user.role)
  // El portal web es solo para fundaciones: cualquier otra sesión se cierra
  useEffect(() => { if (forbidden) signOut() }, [forbidden, signOut])
  if (loading) return <main className="flex min-h-screen flex-col items-center justify-center gap-8 p-5"><Brand to="/login" /><Feedback kind="loading" title="Cargando sesión…" /></main>
  if (!user || forbidden) return <Navigate to="/login" replace />
  return <Outlet />
}

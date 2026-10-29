import { Navigate, Outlet } from 'react-router'
import Brand from './Brand'
import Feedback from './Feedback'
import { useAuth } from '../hooks/useAuth'
import { homeFor } from '../services/auth'

// Deja pasar solo a usuarios con sesión y un rol permitido; al resto los redirige
export default function RequireAuth({ roles }: { roles: string[] }) {
  const { user, loading } = useAuth()
  if (loading) return <main className="flex min-h-screen flex-col items-center justify-center gap-8 p-5"><Brand to="/login" /><Feedback kind="loading" title="Cargando sesión…" /></main>
  if (!user) return <Navigate to="/login" replace />
  if (!roles.includes(user.role)) return <Navigate to={homeFor(user)} replace />
  return <Outlet />
}

import { Navigate, Outlet } from 'react-router'
import { LoaderCircle } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'
import { homeFor } from '../services/auth'

// Deja pasar solo a usuarios con sesión y un rol permitido; al resto los redirige
export default function RequireAuth({ roles }: { roles: string[] }) {
  const { user, loading } = useAuth()
  if (loading) return <div role="status" className="flex min-h-screen items-center justify-center gap-3 text-stone-600"><LoaderCircle className="animate-spin" size={23} />Cargando sesión…</div>
  if (!user) return <Navigate to="/login" replace />
  if (!roles.includes(user.role)) return <Navigate to={homeFor(user)} replace />
  return <Outlet />
}

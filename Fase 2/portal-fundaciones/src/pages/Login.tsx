import { useState } from 'react'
import type { FormEvent } from 'react'
import { Navigate } from 'react-router'
import Brand from '../components/Brand'
import ThemeToggle from '../components/ThemeToggle'
import Feedback from '../components/Feedback'
import { useAuth } from '../hooks/useAuth'
import axios from 'axios'
import { errorMessage } from '../services/api'

const inputClass = 'mt-2 w-full rounded-xl border border-base-200 bg-surface px-4 py-3 text-sm placeholder:text-base-400 hover:border-base-300'

export default function Login() {
  const { user, loading, signIn } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  // Con sesión iniciada no tiene sentido ver el login: se va a su inicio
  if (loading) return <main className="flex min-h-screen flex-col items-center justify-center gap-8 p-5"><Brand to="/login" /><Feedback kind="loading" title="Cargando sesión…" /></main>
  if (!loading && user) return <Navigate to="/" replace />

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)
    setSubmitting(true)
    try {
      await signIn(email, password, 'foundation')
    } catch (err) {
      // 403: la cuenta existe pero no es de fundación; el mensaje del backend habla de pestañas que ya no existen
      setError(axios.isAxiosError(err) && err.response?.status === 403
        ? 'Esta cuenta no tiene acceso al portal de fundaciones. Los adoptantes usan la app móvil.'
        : errorMessage(err, 'No pudimos iniciar sesión. Inténtalo nuevamente.'))
      setSubmitting(false)
    }
  }

  return (
    <main className="relative flex min-h-screen flex-col items-center justify-center px-4 py-10">
      <div className="absolute right-4 top-4"><ThemeToggle /></div>
      <div className="mb-8"><Brand to="/login" /></div>

      <section className="w-full max-w-md rounded-3xl border border-base-200 bg-surface p-6 sm:p-8" aria-labelledby="login-title">
        <h1 id="login-title" className="text-2xl font-bold tracking-tight">Portal de fundaciones</h1>
        <p className="mt-2 text-sm text-base-500">Inicia sesión para gestionar a tus rescatados.</p>

        <form onSubmit={handleSubmit} className="mt-7 space-y-5">
          <label className="block text-sm font-medium">Correo electrónico
            <input className={inputClass} type="email" value={email} onChange={e => setEmail(e.target.value)} required autoComplete="email" placeholder="contacto@fundacion.cl" />
          </label>
          <label className="block text-sm font-medium">Contraseña
            <input className={inputClass} type="password" value={password} onChange={e => setPassword(e.target.value)} required autoComplete="current-password" placeholder="Tu contraseña" />
          </label>

          {error && <Feedback kind="error" title={error} compact />}
          {submitting && <Feedback kind="loading" title="Iniciando sesión…" compact />}

          <button type="submit" disabled={submitting || loading} className="button-primary w-full">
            Iniciar sesión
          </button>
        </form>

        <p className="mt-6 border-t border-base-100 pt-6 text-center text-sm text-base-500">
          
        </p>
      </section>
    </main>
  )
}

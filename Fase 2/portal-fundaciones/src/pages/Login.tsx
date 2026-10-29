import { useState } from 'react'
import type { FormEvent } from 'react'
import { Navigate } from 'react-router'
import { Building2, UserRound } from 'lucide-react'
import Brand from '../components/Brand'
import Feedback from '../components/Feedback'
import type { LucideIcon } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'
import { errorMessage } from '../services/api'
import { homeFor } from '../services/auth'
import type { AccountType } from '../services/auth'

const tabs: { id: AccountType; label: string; icon: LucideIcon }[] = [
  { id: 'user', label: 'Usuario', icon: UserRound },
  { id: 'foundation', label: 'Fundación', icon: Building2 },
]

const inputClass = 'mt-2 w-full rounded-xl border border-base-200 bg-surface px-4 py-3 text-sm placeholder:text-base-400 hover:border-base-300'

export default function Login() {
  const { user, loading, signIn, signUp } = useAuth()
  const [tab, setTab] = useState<AccountType>('user')
  const [registering, setRegistering] = useState(false)
  const [fullName, setFullName] = useState('')
  const [rut, setRut] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)

  // Con sesión iniciada no tiene sentido ver el login: se va a su inicio
  if (loading) return <main className="flex min-h-screen flex-col items-center justify-center gap-8 p-5"><Brand to="/login" /><Feedback kind="loading" title="Cargando sesión…" /></main>
  if (!loading && user) return <Navigate to={homeFor(user)} replace />

  const isRegister = tab === 'user' && registering
  const title = isRegister ? 'Crea tu cuenta' : tab === 'user' ? 'Hola de nuevo' : 'Portal de fundaciones'
  const description = isRegister ? 'Regístrate para encontrar a tu próximo compañero.' : tab === 'user' ? 'Inicia sesión para encontrar a tu próximo compañero.' : 'Inicia sesión para gestionar a tus rescatados.'

  function changeTab(next: AccountType) {
    setTab(next)
    setRegistering(false)
    setError(null)
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)
    setSubmitting(true)
    try {
      if (isRegister) await signUp(email, rut, password, fullName)
      else await signIn(email, password, tab)
    } catch (err) {
      setError(errorMessage(err, 'No pudimos iniciar sesión. Inténtalo nuevamente.'))
      setSubmitting(false)
    }
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-center px-4 py-10">
      <div className="mb-8"><Brand to="/login" /></div>

      <section className="w-full max-w-md rounded-3xl border border-base-200 bg-surface p-6 sm:p-8" aria-labelledby="login-title">
        <div role="tablist" aria-label="Tipo de cuenta" className="grid grid-cols-2 gap-1 rounded-xl bg-base-100 p-1">
          {tabs.map(({ id, label, icon: Icon }) => (
            <button key={id} type="button" role="tab" aria-selected={tab === id} onClick={() => changeTab(id)}
              className={`flex items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-semibold transition-colors ${tab === id ? 'bg-surface text-brand-800 shadow-sm' : 'text-base-500 hover:text-base-900'}`}>
              <Icon size={17} />{label}
            </button>
          ))}
        </div>

        <h1 id="login-title" className="mt-8 text-2xl font-bold tracking-tight">{title}</h1>
        <p className="mt-2 text-sm text-base-500">{description}</p>

        <form onSubmit={handleSubmit} className="mt-7 space-y-5">
          {isRegister && (
            <label className="block text-sm font-medium">Nombre completo
              <input className={inputClass} value={fullName} onChange={e => setFullName(e.target.value)} required minLength={2} autoComplete="name" placeholder="Tu nombre" />
            </label>
          )}
          {isRegister && (
            <label className="block text-sm font-medium">RUT
              <input className={inputClass} value={rut} onChange={e => setRut(e.target.value)} required autoComplete="off" placeholder="12.345.678-5" />
            </label>
          )}
          <label className="block text-sm font-medium">Correo electrónico
            <input className={inputClass} type="email" value={email} onChange={e => setEmail(e.target.value)} required autoComplete="email" placeholder={tab === 'user' ? 'tucorreo@ejemplo.cl' : 'contacto@fundacion.cl'} />
          </label>
          <label className="block text-sm font-medium">Contraseña
            <input className={inputClass} type="password" value={password} onChange={e => setPassword(e.target.value)} required minLength={isRegister ? 8 : undefined} autoComplete={isRegister ? 'new-password' : 'current-password'} placeholder={isRegister ? 'Mínimo 8 caracteres' : 'Tu contraseña'} />
          </label>

          {error && <Feedback kind="error" title={error} compact />}
          {submitting && <Feedback kind="loading" title={isRegister ? 'Creando tu cuenta…' : 'Iniciando sesión…'} compact />}

          <button type="submit" disabled={submitting || loading} className="button-primary w-full">
            {isRegister ? 'Crear cuenta' : 'Iniciar sesión'}
          </button>
        </form>

        <p className="mt-6 border-t border-base-100 pt-6 text-center text-sm text-base-500">
          {tab === 'user'
            ? <>{isRegister ? '¿Ya tienes cuenta?' : '¿No tienes cuenta?'} <button type="button" onClick={() => { setRegistering(!registering); setError(null) }} className="font-semibold text-brand-700 hover:underline">{isRegister ? 'Inicia sesión' : 'Regístrate'}</button></>
            : 'Las cuentas de fundación las crea el equipo de Adoptify.'}
        </p>
      </section>
    </main>
  )
}

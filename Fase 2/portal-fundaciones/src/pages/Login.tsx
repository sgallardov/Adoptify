import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { Navigate } from 'react-router'
import Brand from '../components/Brand'
import ThemeToggle from '../components/ThemeToggle'
import Feedback from '../components/Feedback'
import { useAuth } from '../hooks/useAuth'
import axios from 'axios'
import { errorMessage } from '../services/api'
import { resendCode } from '../services/auth'
import type { CodeChallenge } from '../services/auth'
import { cleanCode, isCompleteCode, mustRestart } from '../services/verificationCode'

const inputClass = 'mt-2 w-full rounded-xl border border-base-200 bg-surface px-4 py-3 text-sm placeholder:text-base-400 hover:border-base-300'

export default function Login() {
  const { user, loading, signIn, verifyCode } = useAuth()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  // Verificación en dos pasos (HU-I): con el desafío, la tarjeta pide el código que llegó al correo
  const [challenge, setChallenge] = useState<CodeChallenge | null>(null)
  const [code, setCode] = useState('')
  const [resendIn, setResendIn] = useState(0)

  // Cuenta regresiva de "Reenviar código"
  useEffect(() => {
    if (resendIn <= 0) return
    const timer = setTimeout(() => setResendIn(seconds => seconds - 1), 1000)
    return () => clearTimeout(timer)
  }, [resendIn])

  // Con sesión iniciada no tiene sentido ver el login: se va a su inicio
  if (loading) return <main className="flex min-h-screen flex-col items-center justify-center gap-8 p-5"><Brand to="/login" /><Feedback kind="loading" title="Cargando sesión…" /></main>
  if (!loading && user) return <Navigate to="/" replace />

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError(null)
    setSubmitting(true)
    try {
      const next = await signIn(email, password, 'foundation')
      if (next) {
        setChallenge(next)
        setCode('')
        setResendIn(next.resend_in_seconds)
        setSubmitting(false)
      }
    } catch (err) {
      // 403: la cuenta existe pero no es de fundación; el mensaje del backend habla de pestañas que ya no existen
      setError(axios.isAxiosError(err) && err.response?.status === 403
        ? 'Esta cuenta no tiene acceso al portal de fundaciones. Los adoptantes usan la app móvil.'
        : errorMessage(err, 'No pudimos iniciar sesión. Inténtalo nuevamente.'))
      setSubmitting(false)
    }
  }

  async function handleVerify(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!challenge) return
    if (!isCompleteCode(code)) {
      setError('Ingresa los 6 dígitos del código.')
      return
    }
    setError(null)
    setSubmitting(true)
    try {
      await verifyCode(challenge.challenge_id, code)
    } catch (err) {
      setError(errorMessage(err, 'No pudimos verificar el código. Inténtalo nuevamente.'))
      setCode('')
      setSubmitting(false)
      // Código vencido o agotado: de vuelta a la contraseña para recibir uno nuevo
      if (axios.isAxiosError(err) && mustRestart(err.response?.status, err.response?.data?.detail)) {
        setChallenge(null)
        setPassword('')
      }
    }
  }

  async function handleResend() {
    if (!challenge) return
    setError(null)
    try {
      const fresh = await resendCode(challenge.challenge_id)
      setChallenge(fresh)
      setCode('')
      setResendIn(fresh.resend_in_seconds)
    } catch (err) {
      setError(errorMessage(err, 'No pudimos reenviar el código. Inténtalo nuevamente.'))
    }
  }

  function backToPassword() {
    setChallenge(null)
    setCode('')
    setError(null)
  }

  return (
    <main className="relative flex min-h-screen flex-col items-center justify-center px-4 py-10">
      <div className="absolute right-4 top-4"><ThemeToggle /></div>
      <div className="mb-8"><Brand to="/login" /></div>

      <section className="w-full max-w-md rounded-3xl border border-base-200 bg-surface p-6 sm:p-8" aria-labelledby="login-title">
        {challenge ? (
          <>
            <h1 id="login-title" className="text-2xl font-bold tracking-tight">Revisa tu correo</h1>
            <p className="mt-2 text-sm text-base-500">
              Enviamos un código de 6 dígitos a <strong>{challenge.email_hint}</strong>. Vence en {challenge.expires_in_minutes} minutos.
            </p>

            <form onSubmit={handleVerify} className="mt-7 space-y-5">
              <label className="block text-sm font-medium">Código de verificación
                <input
                  className={`${inputClass} text-center text-2xl tracking-[0.5em]`}
                  value={code}
                  onChange={e => setCode(cleanCode(e.target.value))}
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  autoFocus
                  required
                  placeholder="000000"
                  aria-describedby="code-help"
                />
              </label>
              <p id="code-help" className="sr-only">Escribe los 6 dígitos que llegaron a tu correo</p>

              {error && <Feedback kind="error" title={error} compact />}
              {submitting && <Feedback kind="loading" title="Verificando…" compact />}

              <button type="submit" disabled={submitting} className="button-primary w-full">Verificar</button>
            </form>

            <div className="mt-4 flex flex-wrap items-center justify-between gap-2 text-sm">
              <button type="button" onClick={backToPassword} disabled={submitting} className="font-medium text-base-500 hover:text-base-700">
                Volver
              </button>
              <button type="button" onClick={handleResend} disabled={resendIn > 0 || submitting} className="font-medium text-brand-600 hover:text-brand-700 disabled:text-base-400">
                {resendIn > 0 ? `Reenviar código en ${resendIn} s` : 'Reenviar código'}
              </button>
            </div>
          </>
        ) : (
          <>
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
          </>
        )}

        <p className="mt-6 border-t border-base-100 pt-6 text-center text-sm text-base-500">

        </p>
      </section>
    </main>
  )
}

import { useState } from 'react'
import { Link, useNavigate } from 'react-router'
import { ArrowLeft, LoaderCircle, LocateFixed, Send } from 'lucide-react'
import AppHeader from '../components/AppHeader'
import Feedback from '../components/Feedback'
import type { LatLng } from '../hooks/useMapAnimals'
import { errorMessage } from '../services/api'
import { createReport } from '../services/reports'
import PageHeading from '../components/PageHeading'
import ReportLocationPicker from '../components/ReportLocationPicker'

const MIN_DESCRIPTION = 10

// Formulario para que un usuario reporte un perro abandonado marcando dónde está
export default function ReportDog() {
  const navigate = useNavigate()
  const [position, setPosition] = useState<LatLng | null>(null)
  const [description, setDescription] = useState('')
  const [locating, setLocating] = useState(false)
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function locate() {
    if (!('geolocation' in navigator)) {
      setError('Tu navegador no permite obtener la ubicación. Marca el punto en el mapa.')
      return
    }
    setLocating(true)
    setError(null)
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        setPosition({ lat: coords.latitude, lng: coords.longitude })
        setLocating(false)
      },
      err => {
        setError(err.code === err.PERMISSION_DENIED
          ? 'No diste permiso para usar tu ubicación. Marca el punto en el mapa.'
          : 'No pudimos obtener tu ubicación. Marca el punto en el mapa.')
        setLocating(false)
      },
      { timeout: 10000, maximumAge: 60000 },
    )
  }

  async function submit(event: React.FormEvent) {
    event.preventDefault()
    if (!position) {
      setError('Marca en el mapa dónde está el perro.')
      return
    }
    if (description.trim().length < MIN_DESCRIPTION) {
      setError(`Describe al perro con al menos ${MIN_DESCRIPTION} caracteres.`)
      return
    }
    setSending(true)
    setError(null)
    try {
      await createReport(position, description.trim())
      navigate('/usuario', { state: { reported: true } })
    } catch (err) {
      setError(errorMessage(err, 'No se pudo enviar el reporte. Inténtalo nuevamente.'))
      setSending(false)
    }
  }

  return (
    <div className="min-h-screen">
      <AppHeader>
        <Link to="/usuario" className="inline-flex items-center gap-2 rounded-xl border border-base-200 px-4 py-2 text-sm font-medium text-base-700 hover:bg-base-50"><ArrowLeft size={16} />Volver</Link>
      </AppHeader>
      <main id="contenido" className="mx-auto max-w-3xl px-5 py-8 sm:px-9 sm:py-10">
        <PageHeading eyebrow="Ayuda a un perro" title="Reportar perro abandonado" description="Marca en el mapa dónde viste al perro y cuéntanos cómo está. Las fundaciones cercanas podrán verlo." />

        <form onSubmit={submit} noValidate className="space-y-5">
          <fieldset className="space-y-3">
            <legend className="mb-2 text-sm font-semibold">1. ¿Dónde está el perro?</legend>
            <div className="flex flex-wrap items-center gap-3">
              <button type="button" onClick={locate} disabled={locating} className="inline-flex items-center gap-2 rounded-xl border border-base-200 bg-surface px-4 py-2 text-sm font-medium text-base-700 hover:bg-base-50 disabled:opacity-60">
                {locating ? <LoaderCircle className="animate-spin" size={16} /> : <LocateFixed size={16} />}Usar mi ubicación
              </button>
              <p className="text-sm text-base-500" aria-live="polite">
                {position ? 'Punto marcado. Puedes arrastrarlo para ajustarlo.' : 'O haz clic en el mapa para marcar el lugar.'}
              </p>
            </div>
            <ReportLocationPicker value={position} onChange={setPosition} />
          </fieldset>

          <label className="block">
            <span className="mb-2 block text-sm font-semibold">2. Describe al perro y su estado</span>
            <textarea value={description} onChange={e => setDescription(e.target.value)} rows={4} maxLength={1000} required
              placeholder="Ej.: perro mediano café, con collar rojo, parece herido de una pata. Está cerca del paradero."
              className="w-full rounded-xl border border-base-200 bg-surface p-3 text-sm outline-none focus:border-brand-500 focus:ring-2 focus:ring-brand-100" />
            <span className="mt-1 block text-right text-xs text-base-400">{description.length}/1000</span>
          </label>

          <p className="rounded-xl bg-base-100 p-3 text-xs leading-5 text-base-600">
            El reporte muestra solo la ubicación del perro y la descripción. Tu nombre y tus datos no se publican.
          </p>

          {error && <Feedback kind="error" title={error} compact />}
          {sending && <Feedback kind="loading" title="Enviando reporte…" compact />}

          <button type="submit" disabled={sending} className="button-primary">
            {sending ? <LoaderCircle className="animate-spin" size={17} /> : <Send size={17} />}{sending ? 'Enviando…' : 'Enviar reporte'}
          </button>
        </form>
      </main>
    </div>
  )
}

import { useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { Link, useNavigate } from 'react-router'
import { ArrowLeft, LoaderCircle, LocateFixed, Send } from 'lucide-react'
import AppHeader from '../components/AppHeader'
import Feedback from '../components/Feedback'
import type { LatLng } from '../hooks/useMapAnimals'
import { errorMessage } from '../services/api'
import { createReport } from '../services/reports'
import { MAX_COMMENT, reportFields, reportOptions, reportPayload, toggleCondition, toggleOption, validateReport } from '../services/reportForm'
import type { MultiField, ReportErrors, TextField } from '../services/reportForm'
import PageHeading from '../components/PageHeading'
import ReportLocationPicker from '../components/ReportLocationPicker'
import PhotoPicker from '../components/PhotoPicker'

const inputClass = 'mt-2 w-full rounded-xl border border-base-300 bg-surface px-3 py-2.5 text-base text-base-800 outline-none focus:border-brand-500 focus:ring-2 focus:ring-brand-100'

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <fieldset className="min-w-0 rounded-2xl border border-base-200 bg-surface p-5 sm:p-7">
      <legend className="px-2 text-lg font-bold">{title}</legend>
      {children}
    </fieldset>
  )
}

function FieldError({ id, error }: { id: string; error?: string }) {
  return error ? <p id={`${id}-error`} className="mt-2 text-sm text-danger-700">{error}</p> : null
}

const chipClass = 'inline-flex rounded-full border border-base-300 bg-surface px-4 py-2 text-sm font-medium text-base-700 peer-checked:border-brand-600 peer-checked:bg-brand-600 peer-checked:text-on-accent peer-focus-visible:ring-2 peer-focus-visible:ring-brand-300 hover:bg-base-50 peer-checked:hover:bg-brand-700'

// Opciones como botones: se eligen de un toque, también en el celular.
// Con multiple son casillas (se marcan varias); si no, radio (una sola).
function Choices({ name, label, options, selected, onToggle, error, multiple }: {
  name: string; label: string; options: readonly (readonly [string, string])[]; selected: string[]
  onToggle: (value: string) => void; error?: string; multiple?: boolean
}) {
  return (
    <fieldset aria-invalid={Boolean(error)} aria-describedby={error ? `${name}-error` : undefined}>
      <legend className="text-sm font-semibold">{label}</legend>
      <div className="mt-2 flex flex-wrap gap-2">
        {options.map(([option, text]) => (
          <label key={option} className="cursor-pointer">
            <input type={multiple ? 'checkbox' : 'radio'} name={name} value={option} checked={selected.includes(option)} onChange={() => onToggle(option)} className="peer sr-only" />
            <span className={chipClass}>{text}</span>
          </label>
        ))}
      </div>
      <FieldError id={name} error={error} />
    </fieldset>
  )
}

// Formulario para que un usuario reporte una mascota abandonada: dónde está, cómo es y cómo se encuentra
export default function ReportDog() {
  const navigate = useNavigate()
  const [position, setPosition] = useState<LatLng | null>(null)
  const [fields, setFields] = useState(reportFields)
  const [errors, setErrors] = useState<ReportErrors>({})
  const [photoUrl, setPhotoUrl] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const [locating, setLocating] = useState(false)
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const errorSummary = useRef<HTMLDivElement>(null)

  function change(field: TextField, value: string) {
    setFields(previous => ({ ...previous, [field]: value }))
    setErrors(previous => ({ ...previous, [field]: undefined }))
  }

  function toggle(field: MultiField, value: string) {
    const next = field === 'conditions' ? toggleCondition : toggleOption
    setFields(previous => ({ ...previous, [field]: next(previous[field], value) }))
    setErrors(previous => ({ ...previous, [field]: undefined }))
  }

  function place(value: LatLng) {
    setPosition(value)
    setErrors(previous => ({ ...previous, position: undefined }))
  }

  function locate() {
    if (!('geolocation' in navigator)) {
      setError('Tu navegador no permite obtener la ubicación. Marca el punto en el mapa.')
      return
    }
    setLocating(true)
    setError(null)
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        place({ lat: coords.latitude, lng: coords.longitude })
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
    const validation = validateReport(fields, position)
    if (Object.keys(validation).length || !position) {
      setErrors(validation)
      setError('Revisa los campos indicados antes de enviar.')
      requestAnimationFrame(() => errorSummary.current?.focus())
      return
    }
    setSending(true)
    setError(null)
    try {
      await createReport(reportPayload(fields, position, photoUrl))
      navigate('/usuario', { state: { reported: true } })
    } catch (err) {
      setError(errorMessage(err, 'No se pudo enviar el reporte. Inténtalo nuevamente.'))
      setSending(false)
    }
  }

  function textProps(field: TextField) {
    return {
      id: field, name: field, className: inputClass, value: fields[field],
      'aria-invalid': Boolean(errors[field]), 'aria-describedby': errors[field] ? `${field}-error` : undefined,
      onChange: (event: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => change(field, event.target.value),
    }
  }

  return (
    <div className="min-h-screen">
      <AppHeader>
        <Link to="/usuario" className="inline-flex items-center gap-2 rounded-xl border border-base-200 px-4 py-2 text-sm font-medium text-base-700 hover:bg-base-50"><ArrowLeft size={16} />Volver</Link>
      </AppHeader>
      <main id="contenido" className="mx-auto max-w-3xl px-5 py-8 sm:px-9 sm:py-10">
        <PageHeading eyebrow="Ayuda a una mascota" title="Reportar mascota" description="Marca dónde la viste, cuéntanos cómo es y cómo está. Las fundaciones cercanas podrán verlo. Los campos con * son obligatorios." />

        <form onSubmit={submit} noValidate className="space-y-6" aria-busy={sending}>
          {error && <div ref={errorSummary} tabIndex={-1}><Feedback kind="error" title={error} compact /></div>}

          <Section title="1. ¿Dónde está? *">
            <div className="mb-3 flex flex-wrap items-center gap-3">
              <button type="button" onClick={locate} disabled={locating} className="inline-flex items-center gap-2 rounded-xl border border-base-200 bg-surface px-4 py-2 text-sm font-medium text-base-700 hover:bg-base-50 disabled:opacity-60">
                {locating ? <LoaderCircle className="animate-spin" size={16} /> : <LocateFixed size={16} />}Usar mi ubicación
              </button>
              <p className="text-sm text-base-500" aria-live="polite">
                {position ? 'Punto marcado. Puedes arrastrarlo para ajustarlo.' : 'O haz clic en el mapa para marcar el lugar.'}
              </p>
            </div>
            <ReportLocationPicker value={position} onChange={place} markerLabel="Ubicación de la mascota" />
            <FieldError id="position" error={errors.position} />
          </Section>

          <Section title="2. ¿Cómo es?">
            <div className="space-y-5">
              <Choices name="species" label="Tipo de animal *" options={reportOptions.species} selected={[fields.species]} onToggle={value => change('species', value)} error={errors.species} />
              <Choices name="size" label="Tamaño *" options={reportOptions.size} selected={[fields.size]} onToggle={value => change('size', value)} error={errors.size} />
              <div className="grid gap-5 sm:grid-cols-2">
                <div>
                  <label htmlFor="color" className="text-sm font-semibold">Color *</label>
                  <input {...textProps('color')} required maxLength={60} placeholder="Ej.: café con blanco" />
                  <FieldError id="color" error={errors.color} />
                </div>
                <div>
                  <label htmlFor="weight_kg" className="text-sm font-semibold">Peso aproximado en kg (opcional)</label>
                  <input {...textProps('weight_kg')} type="text" inputMode="decimal" placeholder="Ej.: 12" />
                  <FieldError id="weight_kg" error={errors.weight_kg} />
                </div>
              </div>
              <div>
                <label htmlFor="features" className="text-sm font-semibold">Características (opcional)</label>
                <input {...textProps('features')} maxLength={300} placeholder="Ej.: collar rojo sin placa, mancha en un ojo, parece quiltro" />
                <FieldError id="features" error={errors.features} />
              </div>
            </div>
          </Section>

          <Section title="3. ¿Cómo está?">
            <div className="space-y-5">
              <p className="-mb-2 text-sm text-base-500">Puedes marcar más de una opción.</p>
              <Choices name="conditions" label="Estado *" options={reportOptions.condition} selected={fields.conditions} onToggle={value => toggle('conditions', value)} error={errors.conditions} multiple />
              <Choices name="behaviors" label="Comportamiento al acercarse (opcional)" options={reportOptions.behavior} selected={fields.behaviors} onToggle={value => toggle('behaviors', value)} error={errors.behaviors} multiple />
            </div>
          </Section>

          <Section title="4. Comentarios *">
            <label htmlFor="description" className="sr-only">Comentarios sobre la situación</label>
            <textarea {...textProps('description')} rows={4} maxLength={MAX_COMMENT} required
              placeholder="Cuéntanos la situación: desde cuándo lo ves, si alguien lo cuida, si está en un lugar peligroso…" />
            <div className="flex justify-between gap-3">
              <FieldError id="description" error={errors.description} />
              <span className="ml-auto mt-1 block text-xs text-base-400">{fields.description.length}/{MAX_COMMENT}</span>
            </div>
          </Section>

          <PhotoPicker label="5. Foto (opcional)" value={photoUrl} onChange={setPhotoUrl} onUploadingChange={setUploading} />

          <p className="rounded-xl bg-base-100 p-3 text-xs leading-5 text-base-600">
            El reporte muestra la ubicación, los datos de la mascota, tus comentarios y la foto. Tu nombre y tus datos no se publican.
          </p>

          {sending && <Feedback kind="loading" title="Enviando reporte…" compact />}

          <button type="submit" disabled={sending || uploading} className="button-primary">
            {sending ? <LoaderCircle className="animate-spin" size={17} /> : <Send size={17} />}{sending ? 'Enviando…' : 'Enviar reporte'}
          </button>
        </form>
      </main>
    </div>
  )
}

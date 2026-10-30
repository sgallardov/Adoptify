import { useRef, useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import { Link, useNavigate, useParams } from 'react-router'
import { ArrowLeft, Save } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'
import { useAnimal } from '../hooks/useAnimal'
import type { LatLng } from '../hooks/useMapAnimals'
import { createAnimal, updateAnimal } from '../services/animals'
import type { AnimalResponse } from '../services/animals'
import { animalFields, animalPayload, validateAnimal } from '../services/animalForm'
import type { AnimalFields, FieldErrors } from '../services/animalForm'
import { animalError } from '../services/animalErrors'
import ReportLocationPicker from '../components/ReportLocationPicker'
import AnimalsState from '../components/AnimalsState'
import Feedback from '../components/Feedback'
import PageHeading from '../components/PageHeading'
import NotFound from './NotFound'

const inputClass = 'mt-2 w-full rounded-xl border border-base-300 bg-surface px-3 py-2.5 text-base text-base-800 disabled:opacity-60'

function Field({ label, error, id, children }: { label: string; error?: string; id: string; children: ReactNode }) {
  return <div><label htmlFor={id} className="text-sm font-semibold">{label}</label>{children}{error && <p id={`${id}-error`} className="mt-2 text-sm text-danger-700">{error}</p>}</div>
}

function Editor({ animal }: { animal?: AnimalResponse }) {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [fields, setFields] = useState(() => animalFields(animal))
  const [errors, setErrors] = useState<FieldErrors>({})
  const [message, setMessage] = useState('')
  const [saving, setSaving] = useState(false)
  const inFlight = useRef(false)
  const errorSummary = useRef<HTMLDivElement>(null)
  const adminCreate = user?.role === 'admin' && !animal
  const back = animal ? `/animales/${animal.id}` : '/animales'
  const hasLocation = animal?.latitude != null && animal?.longitude != null
  const coordinateErrors = validateAnimal(fields, false, false)
  const position: LatLng | null = fields.latitude.trim() && fields.longitude.trim() && !coordinateErrors.latitude && !coordinateErrors.longitude
    ? { lat: Number(fields.latitude), lng: Number(fields.longitude) } : null

  function change(field: keyof AnimalFields, value: string) {
    setFields(previous => ({ ...previous, [field]: value }))
    setErrors(previous => ({ ...previous, [field]: undefined }))
  }
  function markLocation(value: LatLng) {
    if (inFlight.current) return
    setFields(previous => ({ ...previous, latitude: value.lat.toFixed(6), longitude: value.lng.toFixed(6) }))
    setErrors(previous => ({ ...previous, latitude: undefined, longitude: undefined }))
  }
  function showError(text: string, fieldErrors: FieldErrors) {
    setMessage(text)
    setErrors(fieldErrors)
    requestAnimationFrame(() => errorSummary.current?.focus())
  }
  async function submit(event: FormEvent) {
    event.preventDefault()
    if (inFlight.current) return
    const validation = validateAnimal(fields, adminCreate, hasLocation)
    if (Object.keys(validation).length) { showError('Revisa los campos indicados antes de guardar.', validation); return }
    inFlight.current = true
    setSaving(true)
    setMessage('')
    setErrors({})
    try {
      const payload = animalPayload(fields, adminCreate, animal?.status ?? 'available')
      // El estado se cambia desde la ficha; editar los datos no sobrescribe un cambio de estado reciente.
      const { status: _status, foundation_id: _foundation, ...changes } = payload
      const saved = animal ? await updateAnimal(animal.id, changes) : await createAnimal(payload)
      navigate(`/animales/${saved.id}`, { replace: true, state: { notice: animal ? 'Los cambios del animal se guardaron correctamente.' : 'El animal se publicó correctamente.' } })
    } catch (error) {
      const failure = animalError(error)
      showError(failure.message, failure.fields)
    } finally { inFlight.current = false; setSaving(false) }
  }
  function props(field: keyof AnimalFields, required = false) {
    return { id: field, name: field, className: inputClass, value: fields[field], required,
      'aria-invalid': Boolean(errors[field]), 'aria-describedby': errors[field] ? `${field}-error` : undefined,
      onChange: (event: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => change(field, event.target.value) }
  }
  function input(field: keyof AnimalFields, label: string, options: { type?: string; required?: boolean; maxLength?: number; min?: number; max?: number; step?: string; placeholder?: string } = {}) {
    return <Field id={field} label={label} error={errors[field]}><input {...props(field, options.required)} {...options} /></Field>
  }
  function select(field: keyof AnimalFields, label: string, options: [string, string][]) {
    return <Field id={field} label={label} error={errors[field]}><select {...props(field, true)}><option value="">Selecciona una opción</option>{options.map(([value, text]) => <option key={value} value={value}>{text}</option>)}</select></Field>
  }

  return <>
    <Link to={back} className="mb-6 inline-flex items-center gap-2 text-sm text-base-600 hover:text-brand-700"><ArrowLeft size={17} />Volver {animal ? 'a la ficha' : 'a Mis casos'}</Link>
    <PageHeading eyebrow="Cada historia importa" title={animal ? `Editar a ${animal.name}` : 'Publicar animal'} description="Completa su historia y marca dónde se encuentra. Los campos con * son obligatorios." />
    <form onSubmit={submit} noValidate className="space-y-6" aria-busy={saving}>
      {message && <div ref={errorSummary} tabIndex={-1}><Feedback kind="error" title={message} /></div>}
      <fieldset disabled={saving} className="min-w-0 rounded-2xl border border-base-200 bg-surface p-5 sm:p-7">
        <legend className="px-2 text-lg font-bold">Datos del animal</legend>
        <div className="grid gap-5 sm:grid-cols-2">
          {input('name', 'Nombre *', { required: true, maxLength: 100 })}
          {select('species', 'Especie *', [['perro', 'Perro'], ['gato', 'Gato']])}
          {select('size', 'Tamaño *', [['pequeño', 'Pequeño'], ['mediano', 'Mediano'], ['grande', 'Grande']])}
          {select('gender', 'Sexo *', [['macho', 'Macho'], ['hembra', 'Hembra']])}
          {input('breed', 'Raza (opcional)', { maxLength: 100 })}
          {input('age_months', 'Edad en meses (opcional)', { type: 'number', min: 0, max: 360, step: '1' })}
          {select('energy_level', 'Nivel de energía *', [['1', '1 · Muy tranquilo'], ['2', '2 · Tranquilo'], ['3', '3 · Moderado'], ['4', '4 · Activo'], ['5', '5 · Muy activo']])}
          {adminCreate && input('foundation_id', 'ID de la fundación responsable *', { required: true, type: 'number', min: 1, step: '1' })}
        </div>
        {adminCreate && <p className="mt-3 text-sm text-base-500">Como administrador, indica el ID de una fundación ya registrada. Las cuentas de fundación publican directamente en su propia fundación.</p>}
        <div className="mt-5 space-y-5">
          <Field id="description" label="Su historia (opcional)" error={errors.description}><textarea {...props('description')} rows={4} maxLength={2000} /></Field>
          {input('photo_url', 'Enlace de la foto (opcional)', { type: 'url', maxLength: 500, placeholder: 'https://…' })}
        </div>
      </fieldset>
      <fieldset disabled={saving} className="min-w-0 rounded-2xl border border-base-200 bg-surface p-5 sm:p-7">
        <legend className="px-2 text-lg font-bold">Ubicación del animal</legend>
        <p className="mb-4 text-sm text-base-600">Haz clic en el mapa o arrastra el marcador. También puedes escribir las coordenadas. {hasLocation ? 'Puedes mover la ubicación guardada a otro punto.' : 'Sin ubicación, el animal se publica pero no aparecerá en búsquedas por cercanía.'}</p>
        <ReportLocationPicker value={position} onChange={markLocation} markerLabel="Ubicación del animal" />
        <div className="mt-5 grid gap-5 sm:grid-cols-2">
          {input('latitude', 'Latitud', { type: 'number', min: -90, max: 90, step: 'any', placeholder: '-33.4489' })}
          {input('longitude', 'Longitud', { type: 'number', min: -180, max: 180, step: 'any', placeholder: '-70.6693' })}
        </div>
      </fieldset>
      {saving && <Feedback kind="loading" title="Guardando animal…" compact />}
      <div className="flex flex-wrap justify-end gap-3">
        <button type="button" disabled={saving} onClick={() => navigate(back)} className="button-secondary">Cancelar</button>
        <button type="submit" disabled={saving} className="button-primary"><Save size={18} />{saving ? 'Guardando…' : animal ? 'Guardar cambios' : 'Publicar animal'}</button>
      </div>
    </form>
  </>
}

function EditAnimal({ id }: { id: string }) {
  const { animal, loading, error, retry } = useAnimal(id)
  if (loading || error) return <AnimalsState loading={loading} retry={retry} />
  if (!animal) return <NotFound />
  return <Editor key={animal.id} animal={animal} />
}

export default function AnimalForm() {
  const { id } = useParams()
  return id ? <EditAnimal key={id} id={id} /> : <Editor />
}

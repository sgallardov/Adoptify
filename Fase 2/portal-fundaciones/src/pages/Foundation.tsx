import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { PawPrint, ShieldCheck } from 'lucide-react'
import { DESCRIPTION_MIN, fetchMyFoundation, locationLabel, updateMyFoundation } from '../services/foundation'
import type { MyFoundation } from '../services/foundation'
import { errorMessage } from '../services/api'
import { mediaUrl, uploadPhoto } from '../services/uploads'
import Feedback from '../components/Feedback'
import PageHeading from '../components/PageHeading'
import MembersSection from '../components/MembersSection'
import AdoptionFormSection from '../components/AdoptionFormSection'

export default function Foundation() {
  const [foundation, setFoundation] = useState<MyFoundation | null>(null)
  const [error, setError] = useState('')
  const [attempt, setAttempt] = useState(0)
  const [editing, setEditing] = useState(false)
  const [description, setDescription] = useState('')
  const [photoUrl, setPhotoUrl] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const [formError, setFormError] = useState('')

  useEffect(() => {
    const controller = new AbortController()
    fetchMyFoundation(controller.signal)
      .then(data => { if (!controller.signal.aborted) { setFoundation(data); setError('') } })
      .catch(() => { if (!controller.signal.aborted) setError('No pudimos cargar el perfil de tu fundación.') })
    return () => controller.abort()
  }, [attempt])

  function startEditing() {
    if (!foundation) return
    setDescription(foundation.description ?? ''); setPhotoUrl(foundation.photo_url); setFormError(''); setEditing(true)
  }
  async function onPhoto(file: File | undefined) {
    if (!file) return
    setFormError('')
    try { setPhotoUrl(await uploadPhoto(file)) } catch (cause) { setFormError(errorMessage(cause, 'No se pudo subir la foto.')) }
  }
  async function save(event: FormEvent) {
    event.preventDefault()
    if (description.trim().length < DESCRIPTION_MIN) { setFormError(`La descripción debe tener al menos ${DESCRIPTION_MIN} caracteres.`); return }
    setSaving(true); setFormError('')
    try { setFoundation(await updateMyFoundation({ description: description.trim(), photo_url: photoUrl })); setEditing(false) }
    catch (cause) { setFormError(errorMessage(cause, 'No se pudo guardar el perfil.')) }
    finally { setSaving(false) }
  }

  const photo = mediaUrl(editing ? photoUrl : foundation?.photo_url ?? null)
  return <>
    <PageHeading eyebrow="Quienes hacen la diferencia" title="Mi fundación" description="La identidad de tu organización dentro de la comunidad Adoptify." />
    {error && <div className="mb-5"><Feedback kind="error" title={error} actionLabel="Reintentar" onAction={() => setAttempt(value => value + 1)} /></div>}
    {!foundation && !error && <Feedback kind="loading" title="Cargando tu fundación…" />}
    {foundation && <section className="overflow-hidden rounded-3xl border border-base-200 bg-surface">
      <div className="flex flex-wrap items-center gap-5 bg-success-50 p-7 sm:p-9">
        {photo ? <img src={photo} alt={`Foto de ${foundation.name}`} className="size-20 rounded-2xl object-cover" />
          : <span className="flex size-20 items-center justify-center rounded-2xl bg-forest text-on-accent"><PawPrint size={40} /></span>}
        <div><h2 className="text-2xl font-bold">{foundation.name}</h2>
          {foundation.is_verified && <p className="mt-2 flex items-center gap-2 text-sm text-success-800"><ShieldCheck size={17} />Organización verificada</p>}</div>
      </div>
      <div className="p-7 sm:p-9">
        <div className="flex items-center justify-between gap-3"><h3 className="font-semibold">Acerca de nosotros</h3>
          {!editing && <button type="button" onClick={startEditing} className="button-secondary">Editar perfil</button>}</div>
        {editing ? <form onSubmit={save} className="mt-3 grid max-w-2xl gap-4">
          <label className="grid gap-1 text-sm font-medium">Descripción (mínimo {DESCRIPTION_MIN} caracteres)
            <textarea value={description} onChange={event => setDescription(event.target.value)} rows={5} maxLength={1000} className="rounded-xl border border-base-300 p-3 font-normal" /></label>
          <label className="grid gap-1 text-sm font-medium">Foto de perfil
            <input type="file" accept="image/*" onChange={event => void onPhoto(event.target.files?.[0])} className="font-normal" /></label>
          {photoUrl && <button type="button" onClick={() => setPhotoUrl(null)} className="button-secondary w-fit">Quitar foto</button>}
          {formError && <p role="alert" className="text-sm text-danger-700">{formError}</p>}
          <div className="flex gap-3"><button disabled={saving} className="button-primary">{saving ? 'Guardando…' : 'Guardar cambios'}</button>
            <button type="button" disabled={saving} onClick={() => setEditing(false)} className="button-secondary">Cancelar</button></div>
        </form> : <p className="mt-3 max-w-2xl text-sm leading-7 text-base-600">{foundation.description ?? 'Aún no agregaste una descripción. Cuéntale a la comunidad quiénes son.'}</p>}
        <dl className="mt-8 grid gap-7 sm:grid-cols-2">
          {[['Correo electrónico', foundation.email], ['Teléfono', foundation.phone ?? 'No registrado'], ['Ubicación', locationLabel(foundation)]].map(([label, value]) => <div key={label}><dt className="text-xs text-base-500">{label}</dt><dd className="mt-2 break-words text-sm font-medium">{value}</dd></div>)}
        </dl>
      </div>
    </section>}
    <AdoptionFormSection />
    <MembersSection />
  </>
}

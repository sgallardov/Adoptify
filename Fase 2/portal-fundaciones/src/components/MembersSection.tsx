import { useCallback, useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { Eye, EyeOff, Pencil, Plus, Save, Trash2, Users, X } from 'lucide-react'
import { errorMessage } from '../services/api'
import { createMember, deleteMember, fetchMembers, updateMember } from '../services/members'
import type { Member } from '../services/members'
import { emptyMember, memberFields, validateMember } from '../services/memberForm'
import type { MemberErrors, MemberFields } from '../services/memberForm'
import { useAuth } from '../hooks/useAuth'
import Feedback from './Feedback'

const inputClass = 'mt-2 w-full rounded-xl border border-base-300 bg-surface px-3 py-2.5 text-base text-base-800 disabled:opacity-60'
const money = new Intl.NumberFormat('es-CL', { style: 'currency', currency: 'CLP', maximumFractionDigits: 2 })
const formatDate = (iso: string) => new Date(`${iso}T12:00:00`).toLocaleDateString('es-CL', { day: 'numeric', month: 'long', year: 'numeric' })

function MemberForm({ initial, editing, onCancel, onSaved }: { initial: MemberFields; editing: number | null; onCancel: () => void; onSaved: (member: Member) => void }) {
  const [fields, setFields] = useState(initial)
  const [errors, setErrors] = useState<MemberErrors>({})
  const [message, setMessage] = useState('')
  const [saving, setSaving] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    if (saving) return
    const validation = validateMember(fields)
    if (Object.keys(validation).length) { setErrors(validation); return }
    setSaving(true); setMessage('')
    try {
      onSaved(editing === null ? await createMember(fields) : await updateMember(editing, fields))
    } catch (error) {
      setMessage(errorMessage(error, 'No pudimos guardar el socio. Inténtalo nuevamente.'))
      setSaving(false)
    }
  }
  const change = <K extends keyof MemberFields>(key: K, value: MemberFields[K]) => {
    setFields(previous => ({ ...previous, [key]: value }))
    if (key in errors) setErrors(previous => ({ ...previous, [key]: undefined }))
  }

  return <form onSubmit={submit} noValidate aria-label={editing === null ? 'Agregar socio' : 'Editar socio'} className="mt-6 rounded-2xl border border-base-200 bg-base-50 p-5">
    {message && <div className="mb-4"><Feedback kind="error" compact title={message} /></div>}
    <div className="grid gap-5 sm:grid-cols-3">
      <div><label htmlFor="member-name" className="text-sm font-semibold">Nombre</label>
        <input id="member-name" className={inputClass} value={fields.name} maxLength={150} aria-invalid={!!errors.name} aria-describedby={errors.name ? 'member-name-error' : undefined} onChange={event => change('name', event.target.value)} />
        {errors.name && <p id="member-name-error" className="mt-2 text-sm text-danger-700">{errors.name}</p>}</div>
      <div><label htmlFor="member-contribution" className="text-sm font-semibold">Aporte (CLP, opcional)</label>
        <input id="member-contribution" inputMode="decimal" className={inputClass} value={fields.contribution} aria-invalid={!!errors.contribution} aria-describedby="member-contribution-help" onChange={event => change('contribution', event.target.value)} />
        <p id="member-contribution-help" className="mt-2 text-xs text-base-500">Solo registro interno: no se cobra ni se publica.</p>
        {errors.contribution && <p className="mt-2 text-sm text-danger-700">{errors.contribution}</p>}</div>
      <div><label htmlFor="member-joined" className="text-sm font-semibold">Fecha de ingreso</label>
        <input id="member-joined" type="date" className={inputClass} value={fields.joined_at} aria-invalid={!!errors.joined_at} onChange={event => change('joined_at', event.target.value)} />
        {errors.joined_at && <p className="mt-2 text-sm text-danger-700">{errors.joined_at}</p>}</div>
    </div>
    <label className="mt-5 flex items-start gap-3 text-sm">
      <input type="checkbox" className="mt-1 size-4" checked={fields.is_public} onChange={event => change('is_public', event.target.checked)} />
      <span><span className="font-semibold">Mostrar en “Nuestros socios”</span><span className="block text-base-500">Se publica solo el nombre y la fecha de ingreso, nunca el aporte.</span></span>
    </label>
    <div className="mt-6 flex flex-wrap gap-3">
      <button type="submit" className="button-primary" disabled={saving}><Save size={17} aria-hidden="true" />{saving ? 'Guardando…' : 'Guardar socio'}</button>
      <button type="button" className="button-secondary" onClick={onCancel} disabled={saving}><X size={17} aria-hidden="true" />Cancelar</button>
    </div>
  </form>
}

export default function MembersSection() {
  const { user } = useAuth()
  const canEdit = user?.role === 'foundation' // un admin no tiene fundación propia para asociar el socio
  const [members, setMembers] = useState<Member[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)
  const [attempt, setAttempt] = useState(0)
  const [form, setForm] = useState<{ id: number | null; fields: MemberFields } | null>(null)
  const [notice, setNotice] = useState('')

  useEffect(() => {
    const controller = new AbortController()
    setLoading(true); setError(false)
    fetchMembers(controller.signal)
      .then(data => { if (!controller.signal.aborted) setMembers(data) })
      .catch(() => { if (!controller.signal.aborted) setError(true) })
      .finally(() => { if (!controller.signal.aborted) setLoading(false) })
    return () => controller.abort()
  }, [attempt])

  const saved = useCallback((member: Member) => {
    setMembers(previous => previous.some(item => item.id === member.id) ? previous.map(item => item.id === member.id ? member : item) : [member, ...previous])
    setForm(null); setNotice('Socio guardado.')
  }, [])

  async function remove(member: Member) {
    if (!window.confirm(`¿Borrar a ${member.name} de tus socios?`)) return
    try {
      await deleteMember(member.id)
      setMembers(previous => previous.filter(item => item.id !== member.id)); setNotice('Socio borrado.')
    } catch (err) { setNotice(errorMessage(err, 'No pudimos borrar el socio. Inténtalo nuevamente.')) }
  }

  return <section aria-labelledby="members-title" className="mt-8 rounded-3xl border border-base-200 bg-surface p-7 sm:p-9">
    <div className="flex flex-wrap items-start justify-between gap-4">
      <div><h2 id="members-title" className="flex items-center gap-2 text-xl font-bold"><Users size={22} aria-hidden="true" />Socios</h2>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-base-600">Registro interno de quienes donan o apoyan a tu fundación. El aporte es privado; en la ficha pública “Nuestros socios” solo aparecen el nombre y la fecha de los que marques como públicos. Aquí no se realizan cobros.</p></div>
      {canEdit && !form && <button type="button" className="button-primary" onClick={() => { setNotice(''); setForm({ id: null, fields: emptyMember() }) }}><Plus size={17} aria-hidden="true" />Agregar socio</button>}
    </div>
    {notice && <p role="status" className="mt-4 text-sm font-medium text-success-800">{notice}</p>}
    {form && <MemberForm key={form.id ?? 'new'} initial={form.fields} editing={form.id} onCancel={() => setForm(null)} onSaved={saved} />}
    <div className="mt-6">
      {loading ? <Feedback kind="loading" title="Cargando socios…" compact />
        : error ? <Feedback kind="error" title="No pudimos cargar tus socios." actionLabel="Reintentar" onAction={() => setAttempt(value => value + 1)} />
        : members.length === 0 ? <Feedback kind="empty" title="Aún no registras socios" description={canEdit ? 'Agrega a las personas que donan o apoyan a tu fundación. Tú decides cuáles se muestran en tu ficha pública.' : 'Todavía no hay socios registrados.'} />
        : <ul className="divide-y divide-base-200 rounded-2xl border border-base-200">
          {members.map(member => <li key={member.id} className="flex flex-wrap items-center justify-between gap-3 p-4">
            <div className="min-w-0"><p className="break-words font-semibold">{member.name}</p>
              <p className="mt-1 text-sm text-base-600">Desde el {formatDate(member.joined_at)}{member.contribution !== null && <> · Aporte {money.format(Number(member.contribution))}</>}</p>
              <p className="mt-2 inline-flex items-center gap-1.5 text-xs font-medium text-base-500">{member.is_public ? <><Eye size={14} aria-hidden="true" />Visible en la ficha pública</> : <><EyeOff size={14} aria-hidden="true" />Solo interno</>}</p></div>
            {canEdit && <div className="flex gap-2">
              <button type="button" className="button-secondary" aria-label={`Editar a ${member.name}`} onClick={() => { setNotice(''); setForm({ id: member.id, fields: memberFields(member) }) }}><Pencil size={16} aria-hidden="true" />Editar</button>
              <button type="button" className="button-secondary" aria-label={`Borrar a ${member.name}`} onClick={() => remove(member)}><Trash2 size={16} aria-hidden="true" />Borrar</button>
            </div>}
          </li>)}
        </ul>}
    </div>
  </section>
}

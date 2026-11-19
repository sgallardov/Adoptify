import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { ArrowDown, ArrowUp, ClipboardList, Plus, Save, Trash2 } from 'lucide-react'
import { errorMessage } from '../services/api'
import { fetchAdoptionForm, saveAdoptionForm } from '../services/adoptionForm'
import { MAX_QUESTIONS, emptyQuestion, kindLabels, questionsPayload, toDraft, validateQuestions } from '../services/adoptionFormEditor'
import type { QuestionDraft } from '../services/adoptionFormEditor'
import type { QuestionKind } from '../services/adoptionForm'
import { useAuth } from '../hooks/useAuth'
import Feedback from './Feedback'

const inputClass = 'mt-2 w-full rounded-xl border border-base-300 bg-surface px-3 py-2.5 text-base text-base-800 disabled:opacity-60'

// Preguntas que la fundación envía por chat a quien quiere adoptar (HU-G3)
export default function AdoptionFormSection() {
  const { user } = useAuth()
  const canEdit = user?.role === 'foundation' // un admin no tiene fundación propia
  const [drafts, setDrafts] = useState<QuestionDraft[] | null>(null)
  const [loadError, setLoadError] = useState(false)
  const [attempt, setAttempt] = useState(0)
  const [errors, setErrors] = useState<Record<number, string>>({})
  const [notice, setNotice] = useState<{ kind: 'success' | 'error'; text: string } | null>(null)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!canEdit) return
    const controller = new AbortController()
    fetchAdoptionForm(controller.signal)
      .then(questions => { if (!controller.signal.aborted) setDrafts(questions.map(toDraft)) })
      .catch(() => { if (!controller.signal.aborted) setLoadError(true) })
    return () => controller.abort()
  }, [attempt, canEdit])

  if (!canEdit) return null

  function update(index: number, changes: Partial<QuestionDraft>) {
    setDrafts(current => current && current.map((draft, i) => i === index ? { ...draft, ...changes } : draft))
    setErrors(current => { const next = { ...current }; delete next[index]; return next })
    setNotice(null)
  }

  // Al mover o borrar cambian los índices: los errores se recalculan al guardar
  function reorder(next: QuestionDraft[]) {
    setDrafts(next); setErrors({}); setNotice(null)
  }

  function move(index: number, offset: -1 | 1) {
    if (!drafts) return
    const next = [...drafts]
    ;[next[index], next[index + offset]] = [next[index + offset], next[index]]
    reorder(next)
  }

  async function submit(event: FormEvent) {
    event.preventDefault()
    if (!drafts || saving) return
    const validation = validateQuestions(drafts)
    setErrors(validation)
    if (Object.keys(validation).length) { setNotice({ kind: 'error', text: 'Revisa las preguntas marcadas.' }); return }
    setSaving(true); setNotice(null)
    try {
      setDrafts((await saveAdoptionForm(questionsPayload(drafts))).map(toDraft))
      setNotice({ kind: 'success', text: 'Formulario guardado. Los que ya enviaste no cambian.' })
    } catch (error) {
      setNotice({ kind: 'error', text: errorMessage(error, 'No pudimos guardar el formulario. Inténtalo nuevamente.') })
    } finally {
      setSaving(false)
    }
  }

  return <section aria-labelledby="adoption-form-title" className="mt-8 rounded-3xl border border-base-200 bg-surface p-7 sm:p-9">
    <h2 id="adoption-form-title" className="flex items-center gap-2 text-xl font-bold"><ClipboardList size={22} aria-hidden="true" />Formulario de adopción</h2>
    <p className="mt-2 max-w-2xl text-sm leading-6 text-base-600">Las preguntas o requisitos que envías desde Mensajes a quien quiere adoptar. La persona responde desde la app una sola vez y sus respuestas quedan en la conversación.</p>
    <div className="mt-6">
      {loadError ? <Feedback kind="error" title="No pudimos cargar tu formulario." actionLabel="Reintentar" onAction={() => { setLoadError(false); setAttempt(value => value + 1) }} />
        : drafts === null ? <Feedback kind="loading" title="Cargando formulario…" compact />
        : <form onSubmit={submit} noValidate aria-label="Preguntas del formulario de adopción">
          {drafts.length === 0 && <Feedback kind="empty" title="Aún no tienes preguntas" description="Agrega al menos una para poder enviar el formulario por el chat." compact />}
          <ol className="space-y-4">
            {drafts.map((draft, index) => <li key={index} className="rounded-2xl border border-base-200 bg-base-50 p-5">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="text-sm font-semibold text-base-600">Pregunta {index + 1}</span>
                <div className="flex gap-1">
                  <button type="button" className="rounded-lg p-2 text-base-600 hover:bg-base-100 disabled:opacity-40" aria-label={`Subir la pregunta ${index + 1}`} disabled={index === 0} onClick={() => move(index, -1)}><ArrowUp size={16} /></button>
                  <button type="button" className="rounded-lg p-2 text-base-600 hover:bg-base-100 disabled:opacity-40" aria-label={`Bajar la pregunta ${index + 1}`} disabled={index === drafts.length - 1} onClick={() => move(index, 1)}><ArrowDown size={16} /></button>
                  <button type="button" className="rounded-lg p-2 text-danger-700 hover:bg-base-100" aria-label={`Borrar la pregunta ${index + 1}`} onClick={() => reorder(drafts.filter((_, i) => i !== index))}><Trash2 size={16} /></button>
                </div>
              </div>
              <div className="mt-3 grid gap-4 sm:grid-cols-[1fr_12rem]">
                <div><label htmlFor={`question-${index}`} className="text-sm font-semibold">Enunciado</label>
                  <input id={`question-${index}`} className={inputClass} value={draft.label} maxLength={200} aria-invalid={index in errors}
                    aria-describedby={index in errors ? `question-${index}-error` : undefined} onChange={event => update(index, { label: event.target.value })} /></div>
                <div><label htmlFor={`question-${index}-kind`} className="text-sm font-semibold">Tipo de respuesta</label>
                  <select id={`question-${index}-kind`} className={inputClass} value={draft.kind} onChange={event => update(index, { kind: event.target.value as QuestionKind })}>
                    {Object.entries(kindLabels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                  </select></div>
              </div>
              {draft.kind === 'choice' && <div className="mt-4"><label htmlFor={`question-${index}-options`} className="text-sm font-semibold">Alternativas (una por línea)</label>
                <textarea id={`question-${index}-options`} rows={3} className={inputClass} value={draft.optionsText} onChange={event => update(index, { optionsText: event.target.value })} /></div>}
              <label className="mt-4 flex items-center gap-3 text-sm">
                <input type="checkbox" className="size-4" checked={draft.required} onChange={event => update(index, { required: event.target.checked })} />Respuesta obligatoria
              </label>
              {errors[index] && <p id={`question-${index}-error`} className="mt-3 text-sm text-danger-700">{errors[index]}</p>}
            </li>)}
          </ol>
          {notice && <p role={notice.kind === 'error' ? 'alert' : 'status'} className={`mt-4 text-sm font-medium ${notice.kind === 'error' ? 'text-danger-700' : 'text-success-800'}`}>{notice.text}</p>}
          <div className="mt-6 flex flex-wrap gap-3">
            <button type="button" className="button-secondary" disabled={drafts.length >= MAX_QUESTIONS} onClick={() => reorder([...drafts, emptyQuestion()])}><Plus size={17} aria-hidden="true" />Agregar pregunta</button>
            <button type="submit" className="button-primary" disabled={saving}><Save size={17} aria-hidden="true" />{saving ? 'Guardando…' : 'Guardar formulario'}</button>
          </div>
        </form>}
    </div>
  </section>
}

import { useEffect, useRef, useState } from 'react'
import type { FormEvent } from 'react'
import { Link } from 'react-router'
import { Check, CircleAlert, MessageCircle, X } from 'lucide-react'
import Feedback from './Feedback'
import { errorMessage } from '../services/api'
import { decideQuestionnaire, fetchQuestionnaire } from '../services/adoptionForm'
import type { Decision, Questionnaire } from '../services/adoptionForm'
import { MAX_DECISION_MESSAGE, defaultDecisionMessage, formatAnswer } from '../services/adoptionFormEditor'

const dateFormat = new Intl.DateTimeFormat('es-CL', { day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit' })

// Postulación por cuestionario (HU-G3) en un pop-up sobre Mis casos: respuestas, lo que no cumple y la decisión.
// Usa <dialog> nativo: atrapa el foco, cierra con Esc y oscurece el fondo.
export default function QuestionnaireDialog({ id, onClose, onDecided }: {
  id: number
  onClose: () => void
  onDecided: (questionnaire: Questionnaire) => void
}) {
  const dialog = useRef<HTMLDialogElement>(null)
  const [questionnaire, setQuestionnaire] = useState<Questionnaire | null>(null)
  const [error, setError] = useState('')
  const [attempt, setAttempt] = useState(0)
  const [choice, setChoice] = useState<Decision | null>(null)
  const [message, setMessage] = useState('')
  const [saving, setSaving] = useState(false)
  const [saveError, setSaveError] = useState('')

  // Sin cleanup: cerrar en el cleanup dispararía onClose en el doble montaje de StrictMode.
  // Al desmontarse, el <dialog> sale del DOM y deja de ser modal solo.
  useEffect(() => {
    const element = dialog.current
    if (element && !element.open) element.showModal()
  }, [])

  useEffect(() => {
    const controller = new AbortController()
    fetchQuestionnaire(id, controller.signal)
      .then(data => { if (!controller.signal.aborted) setQuestionnaire(data) })
      .catch(failure => { if (!controller.signal.aborted) setError(errorMessage(failure, 'No pudimos cargar la postulación.')) })
    return () => controller.abort()
  }, [id, attempt])

  function choose(decision: Decision) {
    if (!questionnaire) return
    setChoice(decision)
    setSaveError('')
    setMessage(defaultDecisionMessage(decision, questionnaire.animal_name, questionnaire.full_name.split(' ')[0]))
  }

  async function submit(event: FormEvent) {
    event.preventDefault()
    if (!questionnaire || !choice || saving || !message.trim()) return
    setSaving(true)
    setSaveError('')
    try {
      const updated = await decideQuestionnaire(questionnaire.id, choice, message.trim())
      setQuestionnaire(updated)
      setChoice(null)
      onDecided(updated)
    } catch (failure) {
      setSaveError(errorMessage(failure, 'No se pudo guardar la decisión. Inténtalo de nuevo.'))
    } finally {
      setSaving(false)
    }
  }

  const flaggedCount = questionnaire?.flagged.filter(Boolean).length ?? 0

  return <dialog ref={dialog} onClose={onClose} aria-labelledby="questionnaire-title"
    className="m-auto w-[min(42rem,calc(100vw-2rem))] rounded-3xl border border-base-200 bg-surface p-0 text-base-900 shadow-xl backdrop:bg-black/50">
    <div className="flex max-h-[85vh] flex-col">
      <header className="flex items-start gap-3 border-b border-base-200 px-6 py-5">
        <div className="min-w-0 flex-1">
          <p className="text-xs font-semibold uppercase tracking-wide text-brand-700">Postulación</p>
          <h2 id="questionnaire-title" className="mt-1 text-lg font-bold">
            {questionnaire ? `${questionnaire.full_name} · ${questionnaire.animal_name}` : 'Cargando postulación…'}
          </h2>
          {questionnaire?.answered_at && <p className="mt-1 text-sm text-base-500">Respondió el {dateFormat.format(new Date(questionnaire.answered_at))}</p>}
        </div>
        <button type="button" onClick={() => dialog.current?.close()} aria-label="Cerrar postulación" className="rounded-lg p-2 text-base-500 hover:bg-base-100"><X size={18} /></button>
      </header>

      <div className="overflow-y-auto px-6 py-5">
        {error && <Feedback kind="error" title={error} actionLabel="Reintentar" onAction={() => { setError(''); setAttempt(value => value + 1) }} compact />}
        {!error && questionnaire === null && <Feedback kind="loading" title="Cargando postulación…" compact />}
        {questionnaire && <>
          <p className={`flex items-center gap-2 rounded-2xl px-4 py-3 text-sm font-semibold ${flaggedCount ? 'bg-danger-50 text-danger-700' : 'bg-success-50 text-success-800'}`}>
            {flaggedCount ? <CircleAlert size={18} aria-hidden="true" /> : <Check size={18} aria-hidden="true" />}
            {flaggedCount === 0 ? 'Cumple con todo lo esperado.' : flaggedCount === 1 ? '1 respuesta no cumple lo esperado.' : `${flaggedCount} respuestas no cumplen lo esperado.`}
          </p>
          <ol className="mt-4 space-y-3" aria-label="Respuestas">
            {questionnaire.questions.map((question, index) => {
              const flagged = questionnaire.flagged[index]
              return <li key={index} className={`rounded-2xl border px-4 py-3 ${flagged ? 'border-danger-200 bg-danger-50' : 'border-base-200 bg-base-50'}`}>
                <p className="text-xs font-semibold text-base-600">{index + 1}. {question.label}</p>
                <div className="mt-1 flex flex-wrap items-center justify-between gap-2">
                  <p className={`whitespace-pre-wrap break-words text-sm ${flagged ? 'font-semibold text-danger-700' : 'text-base-900'}`}>
                    {index < questionnaire.answers.length ? formatAnswer(questionnaire.answers[index]) : 'Sin responder todavía'}
                  </p>
                  {flagged && <span className="rounded-full bg-danger-600 px-2.5 py-0.5 text-xs font-semibold text-on-accent">No cumple</span>}
                </div>
              </li>
            })}
          </ol>
        </>}
      </div>

      {questionnaire && <footer className="border-t border-base-200 px-6 py-5">
        {questionnaire.decision ? <p className={`text-sm font-semibold ${questionnaire.decision === 'accepted' ? 'text-success-800' : 'text-base-700'}`}>
          {questionnaire.decision === 'accepted' ? 'Aceptaste esta postulación' : 'Rechazaste esta postulación'}
          {questionnaire.decided_at && ` el ${dateFormat.format(new Date(questionnaire.decided_at))}`}. El mensaje quedó en el chat.
        </p>
          : !questionnaire.completed ? <p className="text-sm text-base-600">La persona todavía está respondiendo. Podrás decidir cuando termine.</p>
          : choice ? <form onSubmit={submit} aria-label={choice === 'accepted' ? 'Aceptar postulación' : 'Rechazar postulación'}>
            <label htmlFor="decision-message" className="text-sm font-semibold">
              Mensaje que se enviará por el chat {choice === 'accepted' ? 'al aceptar' : 'al rechazar'}
            </label>
            <textarea id="decision-message" rows={4} value={message} maxLength={MAX_DECISION_MESSAGE} autoFocus
              onChange={event => setMessage(event.target.value)} aria-invalid={Boolean(saveError) || !message.trim()}
              className="mt-2 w-full rounded-xl border border-base-300 bg-surface px-3 py-2.5 text-base text-base-800" />
            {!message.trim() && <p className="mt-1 text-sm text-danger-700">Escribe un mensaje para la persona.</p>}
            {saveError && <p role="alert" className="mt-2 text-sm text-danger-700">{saveError}</p>}
            <div className="mt-4 flex flex-wrap justify-end gap-3">
              <button type="button" className="button-secondary" onClick={() => setChoice(null)} disabled={saving}>Volver</button>
              <button type="submit" disabled={saving || !message.trim()}
                className={choice === 'accepted' ? 'button-primary' : 'inline-flex items-center justify-center gap-2 rounded-xl bg-danger-600 px-5 py-3 text-sm font-semibold text-on-accent hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60'}>
                {saving ? 'Enviando…' : choice === 'accepted' ? 'Enviar y aceptar' : 'Enviar y rechazar'}
              </button>
            </div>
          </form>
          : <div className="flex flex-wrap items-center justify-between gap-3">
            <Link to={`/mensajes/${questionnaire.conversation_id}`} className="inline-flex items-center gap-1 text-sm font-semibold text-brand-700 hover:underline">
              <MessageCircle size={16} aria-hidden="true" />Ir al chat
            </Link>
            <div className="flex flex-wrap gap-3">
              <button type="button" onClick={() => choose('rejected')}
                className="inline-flex items-center justify-center gap-2 rounded-xl border border-danger-200 bg-danger-50 px-4 py-2.5 text-sm font-semibold text-danger-700 hover:opacity-90">
                <X size={16} aria-hidden="true" />Rechazar
              </button>
              <button type="button" className="button-primary" onClick={() => choose('accepted')}><Check size={16} aria-hidden="true" />Aceptar</button>
            </div>
          </div>}
      </footer>}
    </div>
  </dialog>
}

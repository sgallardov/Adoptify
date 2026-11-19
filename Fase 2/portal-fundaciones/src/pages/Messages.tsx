import { useEffect, useRef, useState } from 'react'
import type { FormEvent, KeyboardEvent } from 'react'
import { Link, useParams } from 'react-router'
import { ArrowLeft, MessageCircle, Send, UserRound } from 'lucide-react'
import Feedback from '../components/Feedback'
import PageHeading from '../components/PageHeading'
import { errorMessage } from '../services/api'
import {
  CONVERSATIONS_POLL_MS, MAX_MESSAGE_LENGTH, MESSAGES_POLL_MS,
  fetchConversations, fetchMessages, sendMessage,
} from '../services/conversations'
import type { Conversation, Message } from '../services/conversations'
import { usePolling } from '../hooks/usePolling'

const timeFormat = new Intl.DateTimeFormat('es-CL', { hour: '2-digit', minute: '2-digit' })
const dayFormat = new Intl.DateTimeFormat('es-CL', { day: 'numeric', month: 'short' })

function shortDate(iso: string) {
  const date = new Date(iso)
  return date.toDateString() === new Date().toDateString() ? timeFormat.format(date) : dayFormat.format(date)
}

// Chat con interesados y postulados (HU-G2). Se actualiza por sondeo: la lista cada 15 s y el chat abierto cada 10 s.
export default function Messages() {
  const { id } = useParams()
  const selectedId = id === undefined ? null : Number(id)
  const [conversations, setConversations] = useState<Conversation[] | null>(null)
  const [error, setError] = useState('')
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    const controller = new AbortController()
    fetchConversations(controller.signal)
      .then(items => { if (!controller.signal.aborted) setConversations(items) })
      .catch(failure => { if (!controller.signal.aborted) setError(errorMessage(failure, 'No pudimos cargar tus conversaciones.')) })
    return () => controller.abort()
  }, [attempt, selectedId])

  // Un fallo del sondeo no borra lo que ya se ve: se reintenta en la próxima vuelta
  usePolling(signal => {
    fetchConversations(signal).then(items => { if (!signal.aborted) setConversations(items) }).catch(() => {})
  }, CONVERSATIONS_POLL_MS, [])

  function retry() {
    setError('')
    setConversations(null)
    setAttempt(value => value + 1)
  }

  // El mensaje enviado sube la conversación al inicio de la lista sin esperar al sondeo
  function onSent(conversationId: number, message: Message) {
    setConversations(items => {
      if (!items) return items
      const updated = items.map(item => item.id === conversationId
        ? { ...item, last_message: { body: message.body, created_at: message.created_at, from_foundation: message.from_foundation } }
        : item)
      return [...updated.filter(item => item.id === conversationId), ...updated.filter(item => item.id !== conversationId)]
    })
  }

  const selected = conversations?.find(item => item.id === selectedId) ?? null

  return <>
    <PageHeading eyebrow="Chat" title="Mensajes" description="Conversa con las personas interesadas en tus animales o postuladas como hogar temporal. Los mensajes nuevos aparecen solos." />
    {error && <Feedback kind="error" title={error} actionLabel="Reintentar" onAction={retry} />}
    {!error && conversations === null && <Feedback kind="loading" title="Cargando conversaciones…" />}
    {!error && conversations !== null && <div className="grid min-h-[32rem] overflow-hidden rounded-2xl border border-base-200 bg-surface lg:grid-cols-[18rem_1fr]">
      <aside aria-label="Conversaciones" className={`border-base-200 lg:border-r ${selectedId !== null ? 'hidden lg:block' : ''}`}>
        {conversations.length === 0
          ? <div className="p-5"><Feedback kind="empty" title="Aún no tienes conversaciones" description="Abre una desde Mis casos (Interesados) o desde Hogares temporales con el botón Conversar." compact /></div>
          : <ul className="divide-y divide-base-100">
            {conversations.map(item => <li key={item.id}>
              <Link to={`/mensajes/${item.id}`} aria-current={item.id === selectedId ? 'page' : undefined}
                className={`flex items-start gap-3 px-4 py-3.5 transition-colors ${item.id === selectedId ? 'bg-brand-50' : 'hover:bg-base-50'}`}>
                <UserRound size={20} aria-hidden="true" className="mt-0.5 shrink-0 text-brand-700" />
                <span className="min-w-0 flex-1">
                  <span className="flex items-baseline justify-between gap-2">
                    <span className="truncate text-sm font-semibold text-base-900">{item.user_name}</span>
                    {item.last_message && <span className="shrink-0 text-xs text-base-500">{shortDate(item.last_message.created_at)}</span>}
                  </span>
                  <span className="block truncate text-sm text-base-500">
                    {item.last_message ? `${item.last_message.from_foundation ? 'Tú: ' : ''}${item.last_message.body}` : 'Sin mensajes todavía'}
                  </span>
                </span>
              </Link>
            </li>)}
          </ul>}
      </aside>
      <section aria-label="Conversación" className={`min-w-0 flex-col ${selectedId === null ? 'hidden lg:flex' : 'flex'}`}>
        {selectedId === null && <div className="m-auto max-w-xs p-8 text-center text-sm text-base-500">
          <MessageCircle size={28} aria-hidden="true" className="mx-auto mb-3 text-brand-600" />Elige una conversación para ver los mensajes.
        </div>}
        {selectedId !== null && !selected && <div className="p-5">
          <Feedback kind="error" title="No encontramos esta conversación" description="Puede que no pertenezca a tu fundación." compact />
          <Link to="/mensajes" className="button-secondary mt-4"><ArrowLeft size={16} />Volver a mensajes</Link>
        </div>}
        {selected && <ChatPanel key={selected.id} conversation={selected} onSent={message => onSent(selected.id, message)} />}
      </section>
    </div>}
  </>
}

function ChatPanel({ conversation, onSent }: { conversation: Conversation; onSent: (message: Message) => void }) {
  const [messages, setMessages] = useState<Message[] | null>(null)
  const [error, setError] = useState('')
  const [attempt, setAttempt] = useState(0)
  const [draft, setDraft] = useState('')
  const [sending, setSending] = useState(false)
  const [sendError, setSendError] = useState('')
  const bottom = useRef<HTMLDivElement>(null)
  const lastId = messages?.at(-1)?.id

  useEffect(() => {
    const controller = new AbortController()
    fetchMessages(conversation.id, controller.signal)
      .then(items => { if (!controller.signal.aborted) setMessages(items) })
      .catch(failure => { if (!controller.signal.aborted) setError(errorMessage(failure, 'No pudimos cargar los mensajes.')) })
    return () => controller.abort()
  }, [conversation.id, attempt])

  // Solo pide lo posterior al último mensaje visto
  usePolling(signal => {
    if (messages === null) return
    fetchMessages(conversation.id, signal, lastId ?? 0)
      .then(items => { if (!signal.aborted && items.length) setMessages(current => merge(current, items)) })
      .catch(() => {})
  }, MESSAGES_POLL_MS, [conversation.id, lastId, messages === null])

  useEffect(() => { bottom.current?.scrollIntoView({ block: 'end' }) }, [lastId])

  async function submit(event?: FormEvent) {
    event?.preventDefault()
    const body = draft.trim()
    if (!body || sending) return
    setSending(true)
    setSendError('')
    try {
      const message = await sendMessage(conversation.id, body)
      setMessages(current => merge(current, [message]))
      setDraft('')
      onSent(message)
    } catch (failure) {
      setSendError(errorMessage(failure, 'No se pudo enviar el mensaje. Inténtalo de nuevo.'))
    } finally {
      setSending(false)
    }
  }

  // Enter envía; Shift + Enter agrega una línea
  function onKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      void submit()
    }
  }

  return <>
    <header className="flex items-center gap-3 border-b border-base-200 px-4 py-3.5">
      <Link to="/mensajes" aria-label="Volver a la lista de conversaciones" className="rounded-lg p-1.5 text-base-500 hover:bg-base-100 lg:hidden"><ArrowLeft size={18} /></Link>
      <UserRound size={20} aria-hidden="true" className="text-brand-700" />
      <h2 className="font-semibold">{conversation.user_name}</h2>
    </header>
    <div className="max-h-[28rem] min-h-[18rem] flex-1 overflow-y-auto px-4 py-5" aria-live="polite" aria-label={`Mensajes con ${conversation.user_name}`}>
      {error && <Feedback kind="error" title={error} actionLabel="Reintentar" onAction={() => { setError(''); setAttempt(value => value + 1) }} compact />}
      {!error && messages === null && <Feedback kind="loading" title="Cargando mensajes…" compact />}
      {!error && messages?.length === 0 && <p className="py-10 text-center text-sm text-base-500">Todavía no hay mensajes. Escribe el primero para presentarte.</p>}
      {!error && messages && messages.length > 0 && <ol className="space-y-3">
        {messages.map(message => <li key={message.id} className={`flex ${message.from_foundation ? 'justify-end' : 'justify-start'}`}>
          <div className={`max-w-[80%] rounded-2xl px-4 py-2.5 text-sm ${message.from_foundation ? 'bg-brand-600 text-on-accent' : 'bg-base-100 text-base-900'}`}>
            <p className="whitespace-pre-wrap break-words">{message.body}</p>
            <p className={`mt-1 text-right text-[11px] ${message.from_foundation ? 'text-on-accent/75' : 'text-base-500'}`}>
              {senderLabel(message)}{shortDate(message.created_at)}
            </p>
          </div>
        </li>)}
      </ol>}
      <div ref={bottom} />
    </div>
    <form onSubmit={submit} className="border-t border-base-200 p-4">
      <label htmlFor="message-body" className="sr-only">Escribe un mensaje</label>
      <div className="flex items-end gap-2">
        <textarea id="message-body" rows={2} value={draft} maxLength={MAX_MESSAGE_LENGTH} disabled={messages === null}
          onChange={event => setDraft(event.target.value)} onKeyDown={onKeyDown} placeholder="Escribe un mensaje…"
          aria-describedby="message-help" aria-invalid={Boolean(sendError)}
          className="min-w-0 flex-1 resize-none rounded-xl border border-base-300 bg-surface px-3 py-2.5 text-base text-base-800 disabled:opacity-60" />
        <button type="submit" disabled={!draft.trim() || sending} className="button-primary" aria-label="Enviar mensaje"><Send size={16} aria-hidden="true" /><span className="hidden sm:inline">Enviar</span></button>
      </div>
      <p id="message-help" className="mt-2 flex justify-between gap-2 text-xs text-base-500">
        <span>Enter envía; Shift + Enter agrega una línea.</span><span>{draft.length}/{MAX_MESSAGE_LENGTH}</span>
      </p>
      {sendError && <p role="alert" className="mt-2 text-sm text-danger-700">{sendError}</p>}
    </form>
  </>
}

// Quién escribió, cuando no es obvio: preguntas automáticas del cuestionario (HU-G3) u otro socio
function senderLabel(message: Message): string {
  if (message.kind === 'question' && message.question) return `Pregunta automática ${message.question.index + 1} de ${message.question.total} · `
  if (message.kind === 'answer') return 'Respuesta al cuestionario · '
  return message.from_foundation && !message.mine ? 'Tu fundación · ' : ''
}

// Suma mensajes nuevos sin duplicar los que ya llegaron (el sondeo y el envío pueden traer el mismo)
function merge(current: Message[] | null, incoming: Message[]): Message[] {
  const known = new Set((current ?? []).map(message => message.id))
  return [...(current ?? []), ...incoming.filter(message => !known.has(message.id))].sort((a, b) => a.id - b.id)
}

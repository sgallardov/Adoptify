import { CircleCheck, LoaderCircle, PawPrint, TriangleAlert } from 'lucide-react'

type Props = {
  kind: 'loading' | 'error' | 'empty' | 'success'
  title: string
  description?: string
  actionLabel?: string
  onAction?: () => void
  compact?: boolean
}

/** Patrón único para estados de página y avisos dentro de formularios. */
export default function Feedback({ kind, title, description, actionLabel, onAction, compact = false }: Props) {
  const Icon = kind === 'loading' ? LoaderCircle : kind === 'error' ? TriangleAlert : kind === 'success' ? CircleCheck : PawPrint
  const colors = kind === 'error' ? 'border-danger-200 bg-danger-50 text-danger-900' : kind === 'success' ? 'border-success-200 bg-success-50 text-success-900' : 'border-base-200 bg-surface text-base-600'
  return <div role={kind === 'error' ? 'alert' : 'status'} aria-atomic="true" className={`rounded-2xl border ${colors} ${compact ? 'flex items-start gap-3 p-4' : 'p-6 text-center sm:p-8'}`}>
    <Icon aria-hidden="true" size={compact ? 19 : 28} className={`${compact ? 'mt-0.5 shrink-0' : 'mx-auto mb-3'} ${kind === 'loading' ? 'animate-spin text-brand-600' : ''}`} />
    <div className="min-w-0 break-words"><p className="text-sm font-semibold">{title}</p>
      {description && <p className="mt-2 text-sm leading-6">{description}</p>}
      {onAction && actionLabel && <button type="button" onClick={onAction} className="button-primary mt-5">{actionLabel}</button>}
    </div>
  </div>
}

import { Link } from 'react-router'

/** La misma marca y archivo SVG se usan en todas las rutas y en el favicon. */
export default function Brand({ to = '/', compact = false }: { to?: string; compact?: boolean }) {
  return <Link to={to} aria-label="Adoptify, inicio" className="inline-flex shrink-0 items-center gap-2.5 rounded-xl font-brand">
    <img src="/brand-mark.svg" width={40} height={40} alt="" className="size-10 shrink-0" />
    <span className={`${compact ? 'hidden sm:inline' : ''} text-2xl font-extrabold tracking-tight text-base-900`}>adoptify<span className="text-brand-600">.</span></span>
  </Link>
}

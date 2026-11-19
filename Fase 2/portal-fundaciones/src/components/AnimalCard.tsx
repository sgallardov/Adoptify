import { useState } from 'react'
import { Link } from 'react-router'
import { ArrowUpRight, ClipboardList, Heart, PawPrint } from 'lucide-react'
import type { Animal } from '../data/demo'

export function AnimalPhoto({ animal, large = false }: { animal: Animal; large?: boolean }) {
  const [failed, setFailed] = useState(false)
  return (
    <div className={`relative flex items-center justify-center overflow-hidden bg-base-100 ${large ? 'aspect-square' : 'aspect-[16/10]'}`}>
      {failed || !animal.photo ? <PawPrint size={60} className="text-base-300" aria-label={`Imagen de ${animal.name} no disponible`} /> : <img src={animal.photo} alt={`${animal.name}, ${animal.species}`} onError={() => setFailed(true)} loading="lazy" className="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105" />}
      <span className="absolute left-4 top-4 rounded-full bg-surface/95 px-3 py-1 text-xs font-semibold capitalize text-base-700">{animal.species}</span>
    </div>
  )
}

export function StatusBadge({ status }: { status: Animal['status'] }) {
  const color = status === 'Disponible' ? 'bg-success-50 text-success-800' : status === 'En proceso' ? 'bg-warning-50 text-warning-800' : 'bg-info-50 text-info-800'
  return <span className={`inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[11px] font-semibold ${color}`}><span className="size-1.5 rounded-full bg-current" />{status}</span>
}

// interestedCount: personas que lo marcaron con el corazón (undefined mientras no se conoce).
// toReview: postulaciones respondidas que la fundación todavía no acepta ni rechaza (HU-G3)
export default function AnimalCard({ animal, interestedCount, toReview = 0 }: { animal: Animal; interestedCount?: number; toReview?: number }) {
  return (
    <Link to={`/animales/${animal.id}`} className="group overflow-hidden rounded-2xl border border-base-200 bg-surface transition-shadow hover:shadow-md">
      <AnimalPhoto animal={animal} />
      <div className="p-5">
        <div className="flex items-center justify-between gap-2"><h3 className="text-xl font-bold tracking-tight">{animal.name}</h3><StatusBadge status={animal.status} /></div>
        <p className="mt-2 text-sm text-base-500">{animal.age} · {animal.gender} · {animal.size}</p>
        <div className="mt-5 flex items-center justify-between border-t border-base-100 pt-4 text-xs">
          <span className="flex flex-wrap items-center gap-x-3 gap-y-1">
            {interestedCount !== undefined && <span className="flex items-center gap-1 text-base-600"><Heart size={14} aria-hidden="true" className="text-brand-600" />{interestedCount} {interestedCount === 1 ? 'interesado' : 'interesados'}</span>}
            {toReview > 0 && <span className="flex items-center gap-1 rounded-full bg-brand-100 px-2 py-0.5 font-semibold text-brand-800"><ClipboardList size={13} aria-hidden="true" />{toReview} por revisar</span>}
          </span>
          <span className="flex items-center gap-1 font-semibold text-brand-700">Ver perfil <ArrowUpRight size={15} /></span>
        </div>
      </div>
    </Link>
  )
}

import { Link } from 'react-router'
import { ArrowRight, ArrowUpRight, Check, Heart, PawPrint, Sparkles } from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import { useAnimals } from '../hooks/useAnimals'
import { useAuth } from '../hooks/useAuth'
import AnimalsState from '../components/AnimalsState'
import AnimalCard from '../components/AnimalCard'
import PageHeading from '../components/PageHeading'
import Feedback from '../components/Feedback'

function StatCard({ icon: Icon, title, value, caption }: { icon: LucideIcon; title: string; value: number; caption: string }) {
  return <div className="rounded-2xl border border-base-200 bg-surface p-5"><div className="mb-5 flex items-center justify-between"><p className="text-sm text-base-500">{title}</p><Icon className="text-brand-700" size={19} /></div><p className="text-3xl font-bold tracking-tight">{value.toString().padStart(2, '0')}</p><p className="mt-2 text-xs text-base-500">{caption}</p></div>
}

export default function Dashboard() {
  const { animals, loading, error, retry } = useAnimals()
  const { user } = useAuth()
  return <>
    <PageHeading eyebrow="Un nuevo día, nuevas oportunidades" title={`Hola, ${user?.full_name ?? 'fundación'} 👋`} description="Este es el espacio de quienes hacen posible una segunda oportunidad." />
    <section className="relative mb-7 overflow-hidden rounded-3xl bg-forest p-7 text-surface sm:p-9" aria-label="Bienvenida">
      <PawPrint className="pointer-events-none absolute -right-6 -top-5 size-60 -rotate-12 text-surface/5" strokeWidth={1} />
      <div className="relative max-w-xl">
        <span className="inline-flex items-center gap-2 text-xs font-medium text-success-200"><Sparkles size={15} /> PEQUEÑOS PASOS, GRANDES CAMBIOS</span>
        <h2 className="mb-3 mt-4 text-2xl font-semibold leading-tight sm:text-3xl">Su próximo capítulo<br />empieza contigo.</h2>
        <p className="max-w-md text-sm leading-6 text-success-50/80">Organiza a tus rescatados y conoce sus historias. Cada perfil es una oportunidad de encontrar una familia.</p>
        <Link className="mt-6 inline-flex items-center gap-3 rounded-xl bg-surface px-5 py-3 text-sm font-semibold text-success-950 hover:bg-brand-50" to="/animales">Ver mis animales <ArrowRight size={16} /></Link>
      </div>
    </section>
    {loading || error ? <AnimalsState loading={loading} retry={retry} /> : <>
    <section aria-label="Resumen de animales publicados" className="mb-9 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      <StatCard icon={PawPrint} title="Total de rescatados" value={animals.length} caption="Historias que acompañamos" />
      <StatCard icon={Heart} title="Buscando hogar" value={animals.filter(a => a.status === 'Disponible').length} caption="Listos para una nueva familia" />
      <StatCard icon={ArrowUpRight} title="En proceso" value={animals.filter(a => a.status === 'En proceso').length} caption="Un encuentro más cerca" />
      <StatCard icon={Check} title="Adoptados" value={animals.filter(a => a.status === 'Adoptado').length} caption="Un nuevo comienzo" />
    </section>
    <div className="mb-5 flex items-center justify-between gap-3">
      <div><h2 className="text-xl font-semibold tracking-tight">Historias que esperan un hogar</h2><p className="mt-1 text-sm text-base-500">Conoce a algunos de tus rescatados.</p></div>
      <Link to="/animales" className="inline-flex shrink-0 items-center gap-1 text-sm font-semibold text-brand-700 hover:underline">Ver todos <ArrowRight size={15} /></Link>
    </div>
    <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">{animals.filter(a => a.status === 'Disponible').map(animal => <AnimalCard key={animal.id} animal={animal} />)}</div>
    {animals.every(animal => animal.status !== 'Disponible') && <Feedback kind="empty" title="No hay animales disponibles por el momento" description="Las nuevas historias aparecerán aquí cuando se publiquen." />}
    </>}
  </>
}

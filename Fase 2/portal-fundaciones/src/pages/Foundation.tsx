import { PawPrint, ShieldCheck } from 'lucide-react'
import { foundation } from '../data/demo'
import PageHeading from '../components/PageHeading'

export default function Foundation() {
  return <>
    <PageHeading eyebrow="Quienes hacen la diferencia" title="Mi fundación" description="La identidad de tu organización dentro de la comunidad Adoptify." />
    <section className="overflow-hidden rounded-3xl border border-stone-200 bg-white">
      <div className="flex flex-wrap items-center gap-5 bg-emerald-50 p-7 sm:p-9">
        <span className="flex size-20 items-center justify-center rounded-2xl bg-[#163d35] text-white"><PawPrint size={40} /></span>
        <div><h2 className="text-2xl font-bold">{foundation.name}</h2><p className="mt-2 flex items-center gap-2 text-sm text-emerald-800"><ShieldCheck size={17} />Organización de ejemplo</p></div>
      </div>
      <div className="p-7 sm:p-9">
        <h3 className="font-semibold">Acerca de nosotros</h3><p className="mt-3 max-w-2xl text-sm leading-7 text-stone-600">{foundation.description}</p>
        <dl className="mt-8 grid gap-7 sm:grid-cols-2">
          {[['RUT', foundation.rut], ['Correo electrónico', foundation.email], ['Teléfono', foundation.phone], ['Ubicación', foundation.city]].map(([label, value]) => <div key={label}><dt className="text-xs text-stone-500">{label}</dt><dd className="mt-2 break-words text-sm font-medium">{value}</dd></div>)}
        </dl>
      </div>
    </section>
  </>
}

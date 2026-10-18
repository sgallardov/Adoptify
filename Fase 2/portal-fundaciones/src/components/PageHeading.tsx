export default function PageHeading({ eyebrow, title, description }: { eyebrow: string; title: string; description: string }) {
  return <div className="mb-8"><p className="mb-2 text-[11px] font-bold uppercase tracking-[0.18em] text-orange-700">{eyebrow}</p><h1 className="text-3xl font-bold tracking-tight sm:text-4xl">{title}</h1><p className="mt-3 max-w-2xl text-sm leading-6 text-stone-500">{description}</p></div>
}

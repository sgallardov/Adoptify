import { LoaderCircle, TriangleAlert } from 'lucide-react'

export default function AnimalsState({ loading, retry }: { loading: boolean; retry: () => void }) {
  if (loading) return <div role="status" className="flex items-center justify-center gap-3 rounded-2xl border border-stone-200 bg-white p-12 text-stone-600"><LoaderCircle className="animate-spin" size={23} />Cargando animales…</div>
  return <div role="alert" className="rounded-2xl border border-orange-200 bg-orange-50 p-8 text-center"><TriangleAlert className="mx-auto mb-3 text-orange-700" /><h2 className="font-semibold">No pudimos cargar los animales</h2><p className="mt-2 text-sm text-stone-600">Comprueba tu conexión e inténtalo nuevamente.</p><button onClick={retry} className="mt-5 rounded-xl bg-orange-700 px-5 py-3 text-sm font-semibold text-white hover:bg-orange-800">Reintentar</button></div>
}

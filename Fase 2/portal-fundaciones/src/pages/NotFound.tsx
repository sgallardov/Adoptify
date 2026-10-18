import { Link } from 'react-router'
import { PawPrint } from 'lucide-react'

export default function NotFound() {
  return <div className="py-20 text-center"><PawPrint className="mx-auto mb-5 text-orange-600" size={45} /><h1 className="text-3xl font-bold">Esta página no está disponible</h1><p className="mt-3 text-stone-500">Puedes volver al inicio para seguir explorando.</p><Link to="/" className="mt-6 inline-block rounded-xl bg-orange-600 px-5 py-3 text-sm font-semibold text-white">Volver al inicio</Link></div>
}

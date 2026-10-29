import { Link, useParams } from 'react-router'
import { ArrowLeft } from 'lucide-react'
import { useAnimals } from '../hooks/useAnimals'
import AnimalsState from '../components/AnimalsState'
import { AnimalPhoto, StatusBadge } from '../components/AnimalCard'
import NotFound from './NotFound'

export default function AnimalDetail() {
  const { id } = useParams()
  const { animals, loading, error, retry } = useAnimals()
  if (loading || error) return <AnimalsState loading={loading} retry={retry} />
  const animal = animals.find(item => String(item.id) === id)
  if (!animal) return <NotFound />

  return <>
    <Link to="/animales" className="mb-7 inline-flex items-center gap-2 text-sm text-base-600 hover:text-brand-700"><ArrowLeft size={17} />Volver a mis animales</Link>
    <div className="grid overflow-hidden rounded-3xl border border-base-200 bg-surface md:grid-cols-2">
      <AnimalPhoto key={animal.id} animal={animal} large />
      <div className="p-7 sm:p-10">
        <StatusBadge status={animal.status} /><h1 className="mb-2 mt-4 text-4xl font-bold tracking-tight">{animal.name}</h1>
        <p className="capitalize text-base-500">{animal.species} · {animal.size}</p>
        <p className="my-7 leading-7 text-base-600">{animal.description}</p>
        <dl className="grid grid-cols-2 gap-6 border-y border-base-100 py-6">
          {[['Edad', animal.age], ['Sexo', animal.gender], ['Tamaño', animal.size], ['Energía', `${animal.energy} de 5`]].map(([label, value]) => <div key={label}><dt className="text-xs text-base-500">{label}</dt><dd className="mt-1 text-sm font-semibold">{value}</dd></div>)}
        </dl>
      </div>
    </div>
  </>
}

import { useState } from 'react'
import { Search, SlidersHorizontal, PawPrint } from 'lucide-react'
import { useAnimals } from '../hooks/useAnimals'
import AnimalsState from '../components/AnimalsState'
import AnimalCard from '../components/AnimalCard'
import PageHeading from '../components/PageHeading'

export default function Animals() {
  const { animals, loading, error, retry } = useAnimals()
  const [query, setQuery] = useState('')
  const [species, setSpecies] = useState('')
  const [status, setStatus] = useState('')
  const filtered = animals.filter(animal =>
    animal.name.toLocaleLowerCase('es').includes(query.trim().toLocaleLowerCase('es')) &&
    (!species || animal.species === species) && (!status || animal.status === status))

  return <>
    <PageHeading eyebrow="Cada historia importa" title="Mis casos" description="Consulta los animales publicados y encuentra cada una de sus historias." />
    {loading || error ? <AnimalsState loading={loading} retry={retry} /> : <>
    <section aria-label="Filtros de animales" className="mb-7 flex flex-col gap-3 rounded-2xl border border-stone-200 bg-white p-4 md:flex-row">
      <label className="relative flex-1"><Search size={18} className="absolute left-3 top-3 text-stone-400" /><span className="sr-only">Buscar animal por nombre</span><input type="search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Buscar por nombre…" className="w-full rounded-xl border border-stone-200 py-2.5 pl-10 pr-3 text-sm" /></label>
      <label><span className="sr-only">Filtrar por especie</span><select value={species} onChange={event => setSpecies(event.target.value)} className="w-full rounded-xl border border-stone-200 bg-white px-4 py-2.5 text-sm md:w-44"><option value="">Todas las especies</option><option value="perro">Perros</option><option value="gato">Gatos</option></select></label>
      <label><span className="sr-only">Filtrar por estado</span><select value={status} onChange={event => setStatus(event.target.value)} className="w-full rounded-xl border border-stone-200 bg-white px-4 py-2.5 text-sm md:w-44"><option value="">Todos los estados</option><option>Disponible</option><option>En proceso</option><option>Adoptado</option></select></label>
    </section>
    <p aria-live="polite" className="mb-5 flex items-center gap-2 text-sm text-stone-500"><SlidersHorizontal size={15} />{filtered.length} {filtered.length === 1 ? 'animal encontrado' : 'animales encontrados'}</p>
    {filtered.length ? <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">{filtered.map(animal => <AnimalCard key={animal.id} animal={animal} />)}</div> : <div className="rounded-2xl border border-dashed border-stone-300 p-12 text-center"><PawPrint className="mx-auto mb-3 text-stone-400" size={36} /><h2 className="font-semibold">{animals.length ? 'No encontramos animales' : 'Todavía no hay animales publicados'}</h2><p className="mt-2 text-sm text-stone-500">{animals.length ? 'Prueba con otro nombre o cambia los filtros.' : 'Los animales aparecerán aquí cuando estén registrados.'}</p>{animals.length > 0 && <button onClick={() => { setQuery(''); setSpecies(''); setStatus('') }} className="mt-5 text-sm font-semibold text-orange-700 hover:underline">Limpiar filtros</button>}</div>}
    </>}
  </>
}

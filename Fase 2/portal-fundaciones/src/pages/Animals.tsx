import { useEffect, useState } from 'react'
import { fetchInterested } from '../services/interested'
import { Link } from 'react-router'
import { Search, SlidersHorizontal } from 'lucide-react'
import Feedback from '../components/Feedback'
import { useAnimals } from '../hooks/useAnimals'
import AnimalsState from '../components/AnimalsState'
import AnimalCard from '../components/AnimalCard'
import AnimalStatusTabs from '../components/AnimalStatusTabs'
import { countByStatus, inStatus, panelId, tabId } from '../services/animalStatus'
import PageHeading from '../components/PageHeading'
import type { AnimalStatus } from '../data/demo'

// Mensaje de cada pestaña vacía
const emptyByStatus: Record<AnimalStatus, { title: string; description: string }> = {
  available: { title: 'No tienes animales disponibles', description: 'Publica un animal para que las personas puedan conocerlo.' },
  in_process: { title: 'Ningún animal en proceso', description: 'Aquí verás los animales con una adopción en curso.' },
  adopted: { title: 'Todavía no hay adopciones registradas', description: 'Cuando marques un animal como adoptado, aparecerá en esta pestaña.' },
  follow_up: { title: 'Ningún animal en seguimiento', description: 'Pasa un animal adoptado a Seguimiento para acompañar su adaptación.' },
}

export default function Animals() {
  const { animals, loading, error, retry, replace } = useAnimals()
  const [query, setQuery] = useState('')
  const [species, setSpecies] = useState('')
  const [tab, setTab] = useState<AnimalStatus>('available')
  const [interested, setInterested] = useState<Record<number, { count: number; toReview: number }>>({})
  // Conteo de favoritos y de postulaciones por revisar (HU-G3); si falla, las cards no muestran el conteo
  useEffect(() => {
    const controller = new AbortController()
    fetchInterested(controller.signal)
      .then(groups => setInterested(Object.fromEntries(groups.map(group => [group.animal_id, {
        count: group.interested.length,
        toReview: group.interested.filter(person => person.questionnaire?.completed && !person.questionnaire.decision).length,
      }]))))
      .catch(() => {})
    return () => controller.abort()
  }, [])

  // Los filtros de nombre y especie se aplican antes de contar: las pestañas muestran lo que hay dentro
  const found = animals.filter(animal =>
    animal.name.toLocaleLowerCase('es').includes(query.trim().toLocaleLowerCase('es')) &&
    (!species || animal.species === species))
  const counts = countByStatus(found)
  // Cada animal aparece en una sola pestaña: la de su estado actual
  const visible = inStatus(found, tab)
  const filtering = Boolean(query || species)

  return <>
    <PageHeading eyebrow="Cada historia importa" title="Mis animales" description="Consulta los animales publicados y encuentra cada una de sus historias." />
    <div className="mb-6 flex justify-end"><Link to="/animales/nuevo" className="button-primary">Publicar animal</Link></div>
    {loading || error ? <AnimalsState loading={loading} retry={retry} /> : <>
    <section aria-label="Filtros de animales" className="mb-7 flex flex-col gap-3 rounded-2xl border border-base-200 bg-surface p-4 md:flex-row">
      <label className="relative flex-1"><Search size={18} className="absolute left-3 top-3 text-base-400" /><span className="sr-only">Buscar animal por nombre</span><input type="search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Buscar por nombre…" className="w-full rounded-xl border border-base-200 py-2.5 pl-10 pr-3 text-sm" /></label>
      <label><span className="sr-only">Filtrar por especie</span><select value={species} onChange={event => setSpecies(event.target.value)} className="w-full rounded-xl border border-base-200 bg-surface px-4 py-2.5 text-sm md:w-44"><option value="">Todas las especies</option><option value="perro">Perros</option><option value="gato">Gatos</option></select></label>
    </section>
    <AnimalStatusTabs counts={counts} active={tab} onSelect={setTab} />
    <p aria-live="polite" className="mb-5 flex items-center gap-2 text-sm text-base-500"><SlidersHorizontal size={15} />{visible.length} {visible.length === 1 ? 'animal encontrado' : 'animales encontrados'}</p>
    <div role="tabpanel" id={panelId(tab)} aria-labelledby={tabId(tab)}>
      {visible.length
        ? <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3">{visible.map(animal => <AnimalCard key={animal.id} animal={animal} interestedCount={interested[animal.id]?.count} toReview={interested[animal.id]?.toReview} onStatusChange={replace} />)}</div>
        : <Feedback
            kind="empty"
            title={filtering ? 'No encontramos animales' : emptyByStatus[tab].title}
            description={filtering ? 'Prueba con otro nombre o cambia los filtros.' : emptyByStatus[tab].description}
            actionLabel={filtering ? 'Limpiar filtros' : undefined}
            onAction={filtering ? () => { setQuery(''); setSpecies('') } : undefined}
          />}
    </div>
    </>}
  </>
}

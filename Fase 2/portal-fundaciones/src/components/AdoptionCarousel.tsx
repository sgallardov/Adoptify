import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { ArrowLeft, ArrowRight, MapPin, PawPrint } from 'lucide-react'
import type { Animal } from '../data/demo'
import { capitalize } from '../services/animals'

type Props = {
  animals: Animal[]
  selectedId: number | null
  onLocate: (id: number) => void
}

function CarouselPhoto({ animal }: { animal: Animal }) {
  const [failed, setFailed] = useState(false)
  return (
    <div className="relative flex aspect-[4/3] items-center justify-center overflow-hidden bg-brand-50">
      {animal.photo && !failed ? (
        <img src={animal.photo} alt={`${animal.name}, ${animal.species}`} onError={() => setFailed(true)} loading="lazy" className="h-full w-full object-cover" />
      ) : (
        <div className="flex flex-col items-center gap-3 text-brand-700"><PawPrint size={64} strokeWidth={1.3} /><span className="text-sm">Foto pendiente</span></div>
      )}
      <span className="absolute left-4 top-4 rounded-full bg-surface px-3 py-1.5 text-xs font-semibold text-brand-800">Busco un hogar</span>
      {animal.distanceKm != null && <span className="absolute bottom-4 right-4 rounded-full bg-surface px-3 py-1.5 text-xs font-semibold text-base-800">A {animal.distanceKm.toLocaleString('es-CL')} km</span>}
    </div>
  )
}

export default function AdoptionCarousel({ animals, selectedId, onLocate }: Props) {
  const track = useRef<HTMLDivElement>(null)
  const active = useRef(0)
  const [activeIndex, setActiveIndex] = useState(0)
  const currentIndex = Math.min(activeIndex, Math.max(0, animals.length - 1))

  function moveTo(index: number, instant = false) {
    const container = track.current
    const card = container?.children[index] as HTMLElement | undefined
    if (!container || !card) return
    const left = container.scrollLeft + card.getBoundingClientRect().left - container.getBoundingClientRect().left - (container.clientWidth - card.clientWidth) / 2
    container.scrollTo({ left, behavior: instant || window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth' })
  }

  useLayoutEffect(() => {
    const container = track.current
    if (!container) return
    const visible = Number(getComputedStyle(container).getPropertyValue('--visible-cards'))
    // En escritorio, comenzar con tres tarjetas completas y la segunda destacada.
    const initial = animals.length >= visible ? Math.floor(visible / 2) : 0
    active.current = initial
    setActiveIndex(initial)
    moveTo(initial, true)
    const observer = new ResizeObserver(() => moveTo(active.current, true))
    observer.observe(container)
    return () => observer.disconnect()
  }, [animals])

  useEffect(() => {
    const index = animals.findIndex(animal => animal.id === selectedId)
    if (index >= 0) moveTo(index)
  }, [selectedId, animals])

  function updatePosition() {
    const container = track.current
    if (!container) return
    const center = container.getBoundingClientRect().left + container.clientWidth / 2
    let nearest = 0
    let distance = Infinity
    Array.from(container.children).forEach((card, index) => {
      const bounds = card.getBoundingClientRect()
      const candidate = Math.abs(bounds.left + bounds.width / 2 - center)
      if (candidate < distance) { distance = candidate; nearest = index }
    })
    active.current = nearest
    setActiveIndex(nearest)
  }

  return (
    <div role="region" aria-roledescription="carrusel" aria-label="Animales en adopción">
      <p id="carousel-help" className="mb-4 text-sm text-base-500">Desliza las tarjetas o usa las flechas para conocer a tu próximo compañero.</p>
      <div className="adoption-carousel-region">
      <div ref={track} className="adoption-carousel" tabIndex={0} aria-label="Tarjetas de animales" aria-describedby="carousel-help"
        onScroll={updatePosition} onKeyDown={event => {
          if (event.target !== event.currentTarget) return
          if (event.key === 'ArrowRight' || event.key === 'ArrowLeft') {
            event.preventDefault()
            moveTo(Math.max(0, Math.min(animals.length - 1, currentIndex + (event.key === 'ArrowRight' ? 1 : -1))))
          }
        }}>
        {animals.map((animal, index) => (
          <article key={animal.id} role="group" aria-roledescription="diapositiva" aria-label={`${index + 1} de ${animals.length}: ${animal.name}`}
            aria-current={index === currentIndex ? 'true' : undefined}
            className={`flex shrink-0 snap-center snap-always flex-col overflow-hidden rounded-3xl border bg-surface transition-shadow ${index === currentIndex ? 'border-brand-600 shadow-md ring-2 ring-brand-100' : 'border-base-200 shadow-sm'}`}>
            <CarouselPhoto key={`${animal.id}-${animal.photo}`} animal={animal} />
            <div className="flex flex-1 flex-col p-5 sm:p-6">
              <h3 className="text-2xl font-bold tracking-tight">{animal.name}</h3>
              <p className="mt-1 text-sm text-base-600">{capitalize(animal.species)} · {animal.age}</p>
              <div className="mt-3 flex flex-wrap gap-2 text-xs font-medium text-base-700">
                <span className="rounded-full bg-base-100 px-3 py-1">{capitalize(animal.gender)}</span>
                <span className="rounded-full bg-base-100 px-3 py-1">{capitalize(animal.size)}</span>
              </div>
              <p className="mt-4 line-clamp-3 text-sm leading-relaxed text-base-600">{animal.description}</p>
              {animal.foundationName && <p className="mt-3 break-words text-xs font-semibold text-brand-700">{animal.foundationName}</p>}
              <div className="mt-auto pt-5">
                {animal.latitude != null && animal.longitude != null ? (
                  <button className="button-primary w-full" onClick={() => onLocate(animal.id)} aria-label={`Ver a ${animal.name} en el mapa`}><MapPin size={17} />Ver en el mapa</button>
                ) : <p className="rounded-xl bg-base-50 px-3 py-3 text-center text-sm text-base-500">Ubicación no registrada</p>}
              </div>
            </div>
          </article>
        ))}
      </div>
      </div>
      <div className="mt-5 flex items-center justify-center gap-5">
        <button className="button-secondary !rounded-full !p-3" aria-label="Animal anterior" onClick={() => moveTo(currentIndex - 1)} disabled={currentIndex === 0}><ArrowLeft size={22} /></button>
        <button className="button-secondary !rounded-full !p-3" aria-label="Animal siguiente" onClick={() => moveTo(currentIndex + 1)} disabled={currentIndex === animals.length - 1}><ArrowRight size={22} /></button>
      </div>
    </div>
  )
}

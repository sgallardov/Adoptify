export type Animal = {
  id: number
  name: string
  species: string
  age: string
  gender: string
  size: string
  energy: number
  status: string
  photo: string | null
  description: string
  // Datos que solo entrega el backend (la maqueta no los tiene)
  foundationName?: string | null
  latitude?: number | null
  longitude?: number | null
  distanceKm?: number
}

// Datos exclusivos de la maqueta, sin conexión al backend.
export const animals: Animal[] = [
  { id: 1, name: 'Rocky', species: 'perro', age: '1 año y 6 meses', gender: 'Macho', size: 'Mediano', energy: 4, status: 'Disponible', photo: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?auto=format&fit=crop&w=900&q=80', description: 'Juguetón, curioso y siempre listo para un paseo. Rocky disfruta de la compañía y de descubrir nuevos lugares con su familia.' },
  { id: 2, name: 'Luna', species: 'gato', age: '10 meses', gender: 'Hembra', size: 'Pequeño', energy: 2, status: 'Disponible', photo: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?auto=format&fit=crop&w=900&q=80', description: 'Luna es tranquila y cariñosa. Le encantan los rincones soleados y está acostumbrada a vivir en departamento.' },
  { id: 3, name: 'Milo', species: 'perro', age: '8 meses', gender: 'Macho', size: 'Pequeño', energy: 3, status: 'Disponible', photo: 'https://images.unsplash.com/photo-1583511655857-d19b40a7a54e?auto=format&fit=crop&w=900&q=80', description: 'Un cachorro sociable que convierte cualquier momento en un juego. Milo está descubriendo el mundo y busca una familia que lo acompañe.' },
  { id: 4, name: 'Thor', species: 'perro', age: '2 años', gender: 'Macho', size: 'Grande', energy: 5, status: 'En proceso', photo: 'https://images.unsplash.com/photo-1589941013453-ec89f33b5e95?auto=format&fit=crop&w=900&q=80', description: 'Thor es un compañero activo y protector. Disfruta de los espacios amplios y de paseos largos.' },
  { id: 5, name: 'Nina', species: 'gato', age: '3 años', gender: 'Hembra', size: 'Pequeño', energy: 2, status: 'Adoptado', photo: 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?auto=format&fit=crop&w=900&q=80', description: 'Nina encontró una familia que comparte su gusto por las tardes tranquilas. Su historia nos recuerda por qué seguimos adelante.' },
]

export const foundation = {
  name: 'Fundación Garras y Patas',
  rut: '76.452.189-3',
  email: 'contacto@garrasypatas.cl',
  phone: '+56 9 2233 4455',
  city: 'Providencia, Santiago, Región Metropolitana',
  description: 'Acompañamos a animales rescatados en su camino hacia una nueva familia. Trabajamos por su bienestar, su recuperación y una adopción responsable, con el cariño y el compromiso de nuestra comunidad.',
}

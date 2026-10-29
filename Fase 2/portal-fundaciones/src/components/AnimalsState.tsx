import Feedback from './Feedback'

export default function AnimalsState({ loading, retry }: { loading: boolean; retry: () => void }) {
  return loading
    ? <Feedback kind="loading" title="Cargando animales…" />
    : <Feedback kind="error" title="No pudimos cargar los animales" description="Comprueba tu conexión e inténtalo nuevamente." actionLabel="Reintentar" onAction={retry} />
}

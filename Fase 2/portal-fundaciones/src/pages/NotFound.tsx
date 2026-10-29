import { useNavigate } from 'react-router'
import Feedback from '../components/Feedback'

export default function NotFound() {
  const navigate = useNavigate()
  return <div className="py-10"><h1 className="sr-only">Página no encontrada</h1><Feedback kind="empty" title="Esta página no está disponible" description="Puedes volver al inicio para seguir explorando." actionLabel="Volver al inicio" onAction={() => navigate('/')} /></div>
}

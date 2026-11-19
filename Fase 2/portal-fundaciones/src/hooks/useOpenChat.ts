import { useState } from 'react'
import { useNavigate } from 'react-router'
import { errorMessage } from '../services/api'
import { openConversation } from '../services/conversations'

/** Abre (o retoma) el chat con una persona y lleva a Mensajes. `opening` es el user_id en curso.
 *  Con animalId empieza el cuestionario de adopción de esa mascota (HU-G3). */
export function useOpenChat() {
  const navigate = useNavigate()
  const [opening, setOpening] = useState<number | null>(null)
  const [error, setError] = useState('')

  async function openChat(userId: number, animalId?: number) {
    if (opening !== null) return
    setOpening(userId)
    setError('')
    try {
      const conversation = await openConversation(userId, animalId)
      navigate(`/mensajes/${conversation.id}`)
    } catch (failure) {
      setError(errorMessage(failure, 'No pudimos abrir la conversación. Inténtalo de nuevo.'))
      setOpening(null)
    }
  }

  return { openChat, opening, error }
}

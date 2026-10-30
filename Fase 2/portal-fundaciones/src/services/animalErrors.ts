import axios from 'axios'
import { errorMessage } from './api'
import { animalValidationErrors } from './animalForm'

export function animalError(error: unknown) {
  const response = axios.isAxiosError(error) ? error.response : undefined
  const fields = animalValidationErrors(response?.data?.detail)
  let message = 'No pudimos guardar el animal. Inténtalo nuevamente.'
  if (response?.status === 401) message = 'Tu sesión expiró. Vuelve a iniciar sesión.'
  else if (response?.status === 404) message = 'Este animal ya no está disponible o no tienes acceso a él.'
  else if (response?.status === 422) message = typeof response.data?.detail === 'string' ? response.data.detail : 'Revisa los campos indicados antes de guardar.'
  else message = errorMessage(error, message)
  return { message, fields }
}

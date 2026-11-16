import { api } from './api'

export type ApplicationStatus = 'submitted' | 'reviewing' | 'invited_to_chat' | 'rejected' | 'withdrawn' | 'approved'

export type AdoptionApplication = {
  id: number
  animal_id: number
  animal_name: string
  status: ApplicationStatus
  applicant: { user_id: number; full_name: string }
  profile: {
    housing_type: string; has_kids: string; has_pets: string; hours_alone: string
    activity_level?: string | null; experience?: string | null
    wanted_species: string[]; wanted_sizes: string[]; wanted_ages: string[]; accepts_follow_up: boolean
  }
  message?: string | null
  created_at: string
}

export async function fetchFoundationApplications(signal?: AbortSignal) {
  const { data } = await api.get<AdoptionApplication[]>('/adoption-applications/foundation', { signal })
  return data
}

export async function updateApplicationStatus(id: number, status: 'reviewing' | 'invited_to_chat' | 'rejected' | 'approved') {
  const { data } = await api.patch<AdoptionApplication>(`/adoption-applications/${id}/status`, { status })
  return data
}

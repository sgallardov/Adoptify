import { api } from './api'
import { memberPayload } from './memberForm'
import type { MemberFields } from './memberForm'

export type Member = {
  id: number
  foundation_id: number
  name: string
  /** Decimal como texto ("15000.50"); uso interno, nunca se muestra en la ficha pública. */
  contribution: string | null
  joined_at: string
  is_public: boolean
  created_at: string
}

export async function fetchMembers(signal: AbortSignal): Promise<Member[]> {
  const { data } = await api.get<Member[]>('/foundations/me/members', { signal })
  if (!Array.isArray(data)) throw new Error('Respuesta de socios inválida')
  return data
}

export async function createMember(fields: MemberFields): Promise<Member> {
  return (await api.post<Member>('/foundations/me/members', memberPayload(fields))).data
}

export async function updateMember(id: number, fields: MemberFields): Promise<Member> {
  return (await api.put<Member>(`/foundations/me/members/${id}`, memberPayload(fields))).data
}

export async function deleteMember(id: number): Promise<void> {
  await api.delete(`/foundations/me/members/${id}`)
}

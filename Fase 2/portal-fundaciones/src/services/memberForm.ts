import type { Member } from './members'

export type MemberFields = { name: string; contribution: string; joined_at: string; is_public: boolean }
export type MemberErrors = Partial<Record<'name' | 'contribution' | 'joined_at', string>>

export const emptyMember = (today = new Date().toISOString().slice(0, 10)): MemberFields =>
  ({ name: '', contribution: '', joined_at: today, is_public: false })

export function memberFields(member: Member): MemberFields {
  return { name: member.name, contribution: member.contribution ?? '', joined_at: member.joined_at, is_public: member.is_public }
}

export function validateMember(fields: MemberFields): MemberErrors {
  const errors: MemberErrors = {}
  if (!fields.name.trim()) errors.name = 'Escribe el nombre del socio.'
  else if (fields.name.trim().length > 150) errors.name = 'El nombre admite hasta 150 caracteres.'
  const amount = fields.contribution.trim().replace(',', '.')
  if (amount && !/^\d{1,10}(\.\d{1,2})?$/.test(amount)) errors.contribution = 'Usa un monto válido, por ejemplo 15000 (máximo 2 decimales).'
  if (!/^\d{4}-\d{2}-\d{2}$/.test(fields.joined_at) || Number.isNaN(Date.parse(fields.joined_at))) errors.joined_at = 'Indica la fecha de ingreso.'
  return errors
}

export function memberPayload(fields: MemberFields) {
  const amount = fields.contribution.trim().replace(',', '.')
  return { name: fields.name.trim(), contribution: amount || null, joined_at: fields.joined_at, is_public: fields.is_public }
}

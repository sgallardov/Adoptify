// Código de verificación por correo (HU-I): reglas del formulario, sin depender de React ni de axios

// Solo dígitos y como máximo 6, aunque se pegue "123 456" o "Código: 123456"
export function cleanCode(input: string): string {
  return input.replace(/\D/g, '').slice(0, 6)
}

export const isCompleteCode = (code: string): boolean => /^\d{6}$/.test(code)

// El error obliga a volver a la contraseña (código vencido, agotado o ya usado), salvo un código incorrecto
// al que todavía le quedan intentos
export function mustRestart(status: number | undefined, detail: unknown): boolean {
  return status === 401 && !(typeof detail === 'string' && detail.startsWith('El código no es correcto'))
}

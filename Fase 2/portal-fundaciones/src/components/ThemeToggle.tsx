import { Moon, Sun } from 'lucide-react'
import { useTheme } from '../hooks/useTheme'

// Botón para pasar entre modo claro y oscuro; la elección queda guardada en el navegador
export default function ThemeToggle() {
  const { theme, toggle } = useTheme()
  const label = theme === 'dark' ? 'Activar modo claro' : 'Activar modo oscuro'
  return (
    <button type="button" onClick={toggle} aria-label={label} title={label}
      className="inline-flex size-10 shrink-0 items-center justify-center rounded-xl border border-base-200 bg-surface text-base-600 transition-colors hover:bg-base-100 hover:text-base-900">
      {theme === 'dark' ? <Sun size={18} /> : <Moon size={18} />}
    </button>
  )
}

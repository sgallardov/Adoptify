import { useSyncExternalStore } from 'react'

export type Theme = 'light' | 'dark'

// index.html aplica el mismo valor antes de pintar, para que la página no parpadee en blanco
const THEME_KEY = 'adoptify_theme'
const darkQuery = window.matchMedia('(prefers-color-scheme: dark)')
const listeners = new Set<() => void>()

function savedTheme(): Theme | null {
  try {
    const value = localStorage.getItem(THEME_KEY)
    return value === 'light' || value === 'dark' ? value : null
  } catch { return null }
}

// Elección de la persona; mientras no elija, se sigue la apariencia del sistema
let chosen = savedTheme()

function currentTheme(): Theme {
  return chosen ?? (darkQuery.matches ? 'dark' : 'light')
}

function applyTheme() {
  document.documentElement.dataset.theme = currentTheme()
  listeners.forEach(listener => listener())
}

darkQuery.addEventListener('change', applyTheme)

function subscribe(listener: () => void) {
  listeners.add(listener)
  return () => { listeners.delete(listener) }
}

export function setTheme(theme: Theme) {
  chosen = theme
  try { localStorage.setItem(THEME_KEY, theme) } catch { /* Sin almacenamiento: dura hasta recargar */ }
  applyTheme()
}

export function useTheme() {
  const theme = useSyncExternalStore(subscribe, currentTheme)
  return { theme, toggle: () => setTheme(theme === 'dark' ? 'light' : 'dark') }
}

import { useEffect, useRef } from 'react'

/**
 * Llama a `tick` cada `intervalMs` mientras la pestaña está visible, y una vez apenas vuelve a verse.
 * Cada llamada recibe su AbortSignal, que se cancela al desmontar o al cambiar las dependencias.
 */
export function usePolling(tick: (signal: AbortSignal) => void, intervalMs: number, deps: unknown[]) {
  const tickRef = useRef(tick)
  useEffect(() => { tickRef.current = tick })

  useEffect(() => {
    const controller = new AbortController()
    const run = () => { if (document.visibilityState === 'visible') tickRef.current(controller.signal) }
    const timer = window.setInterval(run, intervalMs)
    document.addEventListener('visibilitychange', run)
    return () => {
      controller.abort()
      window.clearInterval(timer)
      document.removeEventListener('visibilitychange', run)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [intervalMs, ...deps])
}

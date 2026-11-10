import { useEffect, useState } from 'react'
import { Eye, HandHeart, Undo2 } from 'lucide-react'
import { fetchReports, markReportSeen, takeReport, untakeReport } from '../services/reports'
import type { Report } from '../services/reports'
import { errorMessage } from '../services/api'
import Feedback from '../components/Feedback'
import PageHeading from '../components/PageHeading'
import VeterinaryMap from '../components/VeterinaryMap'

const labels = { reported: 'Reportado', in_rescue: 'En rescate', resolved: 'Resuelto' }

export default function Reports() {
  const [reports, setReports] = useState<Report[] | null>(null)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState<number | null>(null)
  const [attempt, setAttempt] = useState(0)

  // En desarrollo React monta y desmonta el efecto para detectar errores. La primera petición se aborta;
  // ese aborto no es un fallo de red y no debe dejar una alerta después de que otra petición sí cargó datos.
  useEffect(() => {
    const controller = new AbortController()
    async function load() {
      setError('')
      try {
        const items = await fetchReports(controller.signal)
        if (!controller.signal.aborted) setReports(items)
      } catch {
        if (!controller.signal.aborted) setError('No pudimos cargar los reportes cercanos.')
      }
    }
    void load()
    return () => controller.abort()
  }, [attempt])
  async function action(id: number, run: (id: number) => Promise<Report>) {
    setBusy(id); setError('')
    try { const updated = await run(id); setReports(items => items?.map(item => item.id === id ? { ...item, ...updated } : item) ?? null) }
    catch (cause) { setError(errorMessage(cause, 'No se pudo actualizar el reporte.')) }
    finally { setBusy(null) }
  }
  return <>
    <PageHeading eyebrow="Respuesta coordinada" title="Reportes cercanos" description="Marca los avisos que revisaste o toma un caso para coordinar su rescate." />
    <VeterinaryMap />
    {error && <div className="mb-5"><Feedback kind="error" title={error} actionLabel="Reintentar" onAction={() => setAttempt(value => value + 1)} /></div>}
    {reports === null && !error && <Feedback kind="loading" title="Cargando reportes…" />}
    {reports?.length === 0 && <Feedback kind="empty" title="No hay reportes cercanos" description="Los nuevos avisos aparecerán aquí." />}
    <div className="grid gap-4 lg:grid-cols-2">{reports?.map(report => <article key={report.id} className="rounded-2xl border border-base-200 bg-surface p-5">
      <div className="flex items-start justify-between gap-3"><div><h2 className="font-semibold capitalize">{report.species ?? 'Mascota'} · {report.size ?? 'Tamaño no informado'}</h2><p className="mt-1 text-sm text-base-500">{labels[report.status]}</p></div><span className="rounded-full bg-danger-50 px-3 py-1 text-xs font-semibold text-danger-700">#{report.id}</span></div>
      <p className="mt-4 text-sm leading-6 text-base-700">{report.description}</p>
      {report.foundation_name && <p className="mt-3 text-sm font-medium text-success-800">Caso tomado por {report.foundation_name}</p>}
      {!report.foundation_name && report.seen_at && <p className="mt-3 text-sm text-base-600">Tu fundación ya marcó este reporte como visto.</p>}
      {report.status !== 'resolved' && <div className="mt-5 flex flex-wrap gap-2">
        <button disabled={busy === report.id} onClick={() => action(report.id, markReportSeen)} className="button-secondary"><Eye size={16} />Marcar visto</button>
        {report.status === 'in_rescue' ? <button disabled={busy === report.id} onClick={() => action(report.id, untakeReport)} className="button-secondary"><Undo2 size={16} />Deshacer toma</button> : <button disabled={busy === report.id} onClick={() => action(report.id, takeReport)} className="button-primary"><HandHeart size={16} />Lo tomamos</button>}
      </div>}
    </article>)}</div>
  </>
}

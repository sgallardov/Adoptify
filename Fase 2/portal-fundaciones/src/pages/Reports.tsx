import { useEffect, useState } from 'react'
import { CheckCircle2, HandHeart, Undo2 } from 'lucide-react'
import { DEFAULT_RADIUS_KM, RADIUS_OPTIONS_KM, fetchMyFoundationId, fetchReports, fetchSearchCenter, reportStatusLabels, resolveReport, takeReport, untakeReport } from '../services/reports'
import { canResolve, reportAction } from '../services/reportActions'
import type { Report } from '../services/reports'
import { errorMessage } from '../services/api'
import Feedback from '../components/Feedback'
import PageHeading from '../components/PageHeading'
import ReportsMap from '../components/ReportsMap'

export default function Reports() {
  const [reports, setReports] = useState<Report[] | null>(null)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState<number | null>(null)
  const [attempt, setAttempt] = useState(0)
  const [radiusKm, setRadiusKm] = useState(DEFAULT_RADIUS_KM)
  const [centerNote, setCenterNote] = useState('')
  const [myFoundationId, setMyFoundationId] = useState<number | null>(null)
  // Reporte elegido en el mapa: su tarjeta se resalta
  const [highlighted, setHighlighted] = useState<number | null>(null)

  useEffect(() => {
    const controller = new AbortController()
    void fetchMyFoundationId(controller.signal).then(id => { if (!controller.signal.aborted) setMyFoundationId(id) })
    return () => controller.abort()
  }, [])

  // En desarrollo React monta y desmonta el efecto para detectar errores. La primera petición se aborta;
  // ese aborto no es un fallo de red y no debe dejar una alerta después de que otra petición sí cargó datos.
  useEffect(() => {
    const controller = new AbortController()
    async function load() {
      setError('')
      try {
        const center = await fetchSearchCenter(controller.signal)
        const items = await fetchReports(center, radiusKm, controller.signal)
        if (!controller.signal.aborted) {
          setReports(items)
          setCenterNote(center.fromFoundation ? 'Desde la ubicación de tu fundación.' : 'Tu fundación no tiene ubicación registrada: se muestra la zona de Santiago.')
        }
      } catch {
        if (!controller.signal.aborted) setError('No pudimos cargar los reportes cercanos.')
      }
    }
    void load()
    return () => controller.abort()
  }, [attempt, radiusKm])
  async function action(id: number, run: (id: number) => Promise<Report>) {
    setBusy(id); setError('')
    try { const updated = await run(id); setReports(items => updated.status === 'resolved' ? items?.filter(item => item.id !== id) ?? null : items?.map(item => item.id === id ? { ...item, ...updated } : item) ?? null) }
    catch (cause) { setError(errorMessage(cause, 'No se pudo actualizar el reporte.')) }
    finally { setBusy(null) }
  }
  // "Ver reporte" en el popup del mapa: lleva a su tarjeta (con el foco, para seguir con el teclado)
  function showReport(id: number) {
    setHighlighted(id)
    const card = document.getElementById(`reporte-${id}`)
    card?.scrollIntoView({ behavior: 'smooth', block: 'center' })
    card?.focus({ preventScroll: true })
  }
  return <>
    <PageHeading eyebrow="Respuesta coordinada" title="Reportes cercanos" description="Toma un caso para coordinar su rescate; si te equivocaste, puedes deshacer la toma. Los casos de otra fundación no se pueden tomar." />
    <div className="mb-4 flex flex-wrap items-center gap-3 text-sm"><label className="flex items-center gap-2 font-medium">Radio de búsqueda<select value={radiusKm} onChange={event => setRadiusKm(Number(event.target.value))} className="rounded-lg border border-base-300 px-2 py-1 font-normal">{RADIUS_OPTIONS_KM.map(km => <option key={km} value={km}>{km} km</option>)}</select></label>{centerNote && <span className="text-base-500">{centerNote}</span>}</div>
    <ReportsMap reports={reports} onShowReport={showReport} />
    {error && <div className="mb-5"><Feedback kind="error" title={error} actionLabel="Reintentar" onAction={() => setAttempt(value => value + 1)} /></div>}
    {reports === null && !error && <Feedback kind="loading" title="Cargando reportes…" />}
    {reports?.length === 0 && <Feedback kind="empty" title="No hay reportes cercanos" description="Los nuevos avisos aparecerán aquí." />}
    <div className="grid gap-4 lg:grid-cols-2">{reports?.map(report => <article key={report.id} id={`reporte-${report.id}`} tabIndex={-1} className={`scroll-mt-6 rounded-2xl border bg-surface p-5 outline-none ${highlighted === report.id ? 'border-brand-500 ring-2 ring-brand-500' : 'border-base-200'}`}>
      <div className="flex items-start justify-between gap-3"><div><h2 className="font-semibold capitalize">{report.species ?? 'Mascota'} · {report.size ?? 'Tamaño no informado'}</h2><p className="mt-1 text-sm text-base-500">{reportStatusLabels[report.status]}</p></div><span className="rounded-full bg-danger-50 px-3 py-1 text-xs font-semibold text-danger-700">#{report.id}</span></div>
      <p className="mt-4 text-sm leading-6 text-base-700">{report.description}</p>
      {report.foundation_name && <p className="mt-3 text-sm font-medium text-success-800">Caso tomado por {report.foundation_name}</p>}
      {!report.foundation_name && report.seen_at && <p className="mt-3 text-sm text-base-600">Una fundación ya vio este reporte.</p>}
      {reportAction(report, myFoundationId) === 'take' && <div className="mt-5"><button disabled={busy === report.id} onClick={() => action(report.id, takeReport)} className="button-primary"><HandHeart size={16} />Lo tomamos</button></div>}
      {reportAction(report, myFoundationId) === 'untake' && <div className="mt-5"><button disabled={busy === report.id} onClick={() => action(report.id, untakeReport)} className="button-secondary"><Undo2 size={16} />Deshacer toma</button></div>}
      {canResolve(report, myFoundationId) && <div className="mt-3"><button disabled={busy === report.id} onClick={() => action(report.id, resolveReport)} className="button-secondary"><CheckCircle2 size={16} />Marcar como resuelto</button></div>}
    </article>)}</div>
  </>
}

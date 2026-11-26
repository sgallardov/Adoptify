import { useEffect, useState } from 'react'
import { CheckCircle2, HandHeart, Undo2 } from 'lucide-react'
import { fetchMyFoundation, fetchReports, reportStatusLabels, resolveReport, takeReport, untakeReport } from '../services/reports'
import { canResolve, reportAction } from '../services/reportActions'
import { DEFAULT_REPORT_RADIUS_KM, NO_LOCATION_RADIUS_KM, REPORT_RADIUS_OPTIONS, reportSearchArea } from '../services/reportArea'
import type { MyFoundation, Report } from '../services/reports'
import { errorMessage } from '../services/api'
import Feedback from '../components/Feedback'
import PageHeading from '../components/PageHeading'
import ReportsMap from '../components/ReportsMap'

export default function Reports() {
  const [reports, setReports] = useState<Report[] | null>(null)
  const [error, setError] = useState('')
  const [busy, setBusy] = useState<number | null>(null)
  const [attempt, setAttempt] = useState(0)
  const [radiusKm, setRadiusKm] = useState(DEFAULT_REPORT_RADIUS_KM)
  // undefined mientras se consulta la fundación de la sesión: hasta saber dónde está su sede no se piden reportes
  const [foundation, setFoundation] = useState<MyFoundation | null | undefined>(undefined)
  // Reporte elegido en el mapa: su tarjeta se resalta
  const [highlighted, setHighlighted] = useState<number | null>(null)
  const myFoundationId = foundation?.id ?? null
  // Centro de la búsqueda: la sede de la fundación de la sesión
  const origin = foundation?.origin ?? null

  useEffect(() => {
    const controller = new AbortController()
    void fetchMyFoundation(controller.signal).then(data => { if (!controller.signal.aborted) setFoundation(data) })
    return () => controller.abort()
  }, [])

  // En desarrollo React monta y desmonta el efecto para detectar errores. La primera petición se aborta;
  // ese aborto no es un fallo de red y no debe dejar una alerta después de que otra petición sí cargó datos.
  useEffect(() => {
    if (foundation === undefined) return
    const controller = new AbortController()
    async function load() {
      setError('')
      try {
        // HU-Z: mismo criterio que el mapa de la app (la sede y el radio elegido; sin sede, Santiago a 100 km)
        const items = await fetchReports(reportSearchArea(origin, radiusKm), controller.signal)
        if (!controller.signal.aborted) setReports(items)
      } catch {
        if (!controller.signal.aborted) setError('No pudimos cargar los reportes cercanos.')
      }
    }
    void load()
    return () => controller.abort()
  }, [attempt, foundation, origin, radiusKm])
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
    <div className="mb-5 flex flex-wrap items-end justify-between gap-4 rounded-2xl border border-base-200 bg-surface p-5">
      <div>
        <h2 className="font-semibold">Zona de búsqueda</h2>
        <p className="mt-1 text-sm text-base-600">
          {origin
            ? `Reportes sin resolver a menos de ${radiusKm} km de la ubicación de tu fundación. Son los mismos que ve una persona en la app con esta ubicación y este radio.`
            : `Tu fundación no tiene ubicación registrada: se muestran los reportes sin resolver a menos de ${NO_LOCATION_RADIUS_KM} km de Santiago, igual que la app cuando no tiene tu ubicación.`}
        </p>
      </div>
      {origin && <div>
        <label htmlFor="radio-reportes" className="block text-xs font-semibold text-base-600">Radio de búsqueda</label>
        <select
          id="radio-reportes"
          value={radiusKm}
          onChange={event => { setReports(null); setRadiusKm(Number(event.target.value)) }}
          className="mt-2 rounded-xl border border-base-300 bg-surface px-3 py-2 text-sm"
        >
          {REPORT_RADIUS_OPTIONS.map(km => <option key={km} value={km}>{km} km</option>)}
        </select>
      </div>}
    </div>
    {foundation !== undefined && <ReportsMap center={origin ?? undefined} reports={reports} onShowReport={showReport} />}
    {error && <div className="mb-5"><Feedback kind="error" title={error} actionLabel="Reintentar" onAction={() => setAttempt(value => value + 1)} /></div>}
    {reports === null && !error && <Feedback kind="loading" title="Cargando reportes…" />}
    {reports?.length === 0 && <Feedback kind="empty" title="No hay reportes cercanos" description={origin ? `No hay avisos sin resolver a menos de ${radiusKm} km de tu fundación. Prueba con un radio mayor.` : 'Los nuevos avisos aparecerán aquí.'} />}
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

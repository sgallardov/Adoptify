// HU-T: una sola acción por reporte. Abierto y libre: "Lo tomamos". Tomado por mi fundación: "Deshacer toma".
// Tomado por otra fundación o resuelto: sin acciones.
export type ReportAction = 'take' | 'untake' | null

export function reportAction(
  report: { status: string; taken_by_foundation_id: number | null },
  myFoundationId: number | null,
): ReportAction {
  if (report.status === 'resolved') return null
  if (report.taken_by_foundation_id === null) return 'take'
  return myFoundationId !== null && report.taken_by_foundation_id === myFoundationId ? 'untake' : null
}

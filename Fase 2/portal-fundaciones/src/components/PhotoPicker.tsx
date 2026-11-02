import { useId, useRef, useState } from 'react'
import type { DragEvent } from 'react'
import { ImagePlus, LoaderCircle, RefreshCw, Trash2 } from 'lucide-react'
import { errorMessage } from '../services/api'
import { MAX_PHOTO_MB, photoError } from '../services/photo'
import { mediaUrl, uploadPhoto } from '../services/uploads'

type Props = {
  label: string
  value: string | null
  onChange: (url: string | null) => void
  onUploadingChange?: (uploading: boolean) => void
  error?: string
}

// Botón para subir una foto desde el computador (o arrastrarla). Sube apenas se elige y entrega la URL.
// En el celular, el mismo selector del navegador ofrece la cámara o la galería.
export default function PhotoPicker({ label, value, onChange, onUploadingChange, error }: Props) {
  const id = useId()
  const input = useRef<HTMLInputElement>(null)
  const [uploading, setUploading] = useState(false)
  const [dragging, setDragging] = useState(false)
  const [failure, setFailure] = useState<string | null>(null)
  const message = failure ?? error

  async function choose(file?: File) {
    if (!file || uploading) return
    const invalid = photoError(file)
    if (invalid) { setFailure(invalid); return }
    setFailure(null)
    setUploading(true)
    onUploadingChange?.(true)
    try {
      onChange(await uploadPhoto(file))
    } catch (err) {
      setFailure(errorMessage(err, 'No se pudo subir la foto. Inténtalo nuevamente.'))
    } finally {
      setUploading(false)
      onUploadingChange?.(false)
      if (input.current) input.current.value = ''
    }
  }
  function drop(event: DragEvent) {
    event.preventDefault()
    setDragging(false)
    void choose(event.dataTransfer.files[0])
  }
  const open = () => input.current?.click()

  return (
    <div>
      <span className="text-sm font-semibold">{label}</span>
      <input ref={input} type="file" accept="image/jpeg,image/png" hidden onChange={event => void choose(event.target.files?.[0])} />
      {value && !uploading ? (
        <div className="mt-2 flex flex-wrap items-center gap-4 rounded-xl border border-base-200 bg-surface p-3">
          <img src={mediaUrl(value) ?? undefined} alt="Vista previa de la foto" className="h-24 w-32 rounded-lg object-cover" />
          <div className="flex flex-wrap gap-2">
            <button type="button" onClick={open} aria-describedby={`${id}-hint`} className="button-secondary"><RefreshCw size={16} />Cambiar foto</button>
            <button type="button" onClick={() => { setFailure(null); onChange(null) }} className="inline-flex items-center gap-2 rounded-xl px-4 py-2 text-sm font-medium text-danger-700 hover:bg-base-50"><Trash2 size={16} />Quitar</button>
          </div>
        </div>
      ) : (
        <button type="button" onClick={open} disabled={uploading} aria-describedby={`${id}-hint`}
          onDragOver={event => { event.preventDefault(); setDragging(true) }} onDragLeave={() => setDragging(false)} onDrop={drop}
          className={`mt-2 flex w-full flex-col items-center gap-2 rounded-xl border-2 border-dashed px-4 py-6 text-sm text-base-600 transition-colors hover:border-brand-500 hover:text-brand-700 disabled:opacity-70 ${dragging ? 'border-brand-500 bg-brand-50' : 'border-base-300 bg-base-50'}`}>
          {uploading ? <LoaderCircle className="animate-spin" size={26} /> : <ImagePlus size={26} />}
          <span className="font-semibold">{uploading ? 'Subiendo foto…' : 'Subir foto'}</span>
          {!uploading && <span className="text-xs text-base-500">Haz clic para elegirla o arrástrala aquí</span>}
        </button>
      )}
      <p id={`${id}-hint`} className="mt-2 text-xs text-base-500">JPG o PNG, hasta {MAX_PHOTO_MB} MB.</p>
      {message && <p role="alert" className="mt-2 text-sm text-danger-700">{message}</p>}
    </div>
  )
}

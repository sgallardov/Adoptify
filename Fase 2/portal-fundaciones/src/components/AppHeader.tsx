import type { ReactNode } from 'react'
import Brand from './Brand'

export default function AppHeader({ children }: { children: ReactNode }) {
  return <header className="flex min-h-20 flex-wrap items-center justify-between gap-3 border-b border-base-200 bg-surface px-4 py-3 sm:px-9">
    <Brand compact /><div className="flex min-w-0 flex-wrap items-center gap-2 sm:gap-3">{children}</div>
  </header>
}

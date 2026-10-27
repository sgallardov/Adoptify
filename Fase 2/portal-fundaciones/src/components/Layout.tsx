import { useState } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router'
import { ChevronRight, Heart, House, LogOut, Menu, PawPrint, Users, X } from 'lucide-react'
import { useAuth } from '../hooks/useAuth'

const navigation = [
  { to: '/', label: 'Inicio', icon: House },
  { to: '/animales', label: 'Mis casos', icon: PawPrint },
  { to: '/fundacion', label: 'Mi fundación', icon: Users },
]

function Navigation({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <nav aria-label="Navegación principal" className="space-y-2">
      {navigation.map(({ to, label, icon: Icon }) => (
        <NavLink key={to} to={to} end={to === '/'} onClick={onNavigate}
          className={({ isActive }) => `flex items-center gap-3 rounded-xl px-4 py-3 text-sm font-medium transition-colors ${isActive ? 'bg-orange-50 text-orange-800' : 'text-stone-500 hover:bg-stone-50 hover:text-stone-900'}`}>
          <Icon size={19} />{label}
        </NavLink>
      ))}
    </nav>
  )
}

export default function Layout() {
  const [menuOpen, setMenuOpen] = useState(false)
  const location = useLocation()
  const { user, signOut } = useAuth()
  const initials = (user?.full_name ?? '').split(' ').filter(Boolean).slice(0, 2).map(word => word[0]).join('').toUpperCase()
  const isAnimalsPage = location.pathname.startsWith('/animales')
  const title = isAnimalsPage ? 'Mis casos' : location.pathname === '/fundacion' ? 'Mi fundación' : 'Inicio'

  return (
    <div className="min-h-screen lg:pl-64">
      <a href="#contenido" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-50 focus:bg-white focus:p-3">Saltar al contenido</a>
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 flex-col border-r border-stone-200 bg-white px-6 py-9 lg:flex">
        <Link to="/" aria-label="Adoptify, inicio" className="flex items-center gap-2.5">
          <span className="rounded-xl bg-orange-600 p-2 text-white"><PawPrint size={24} /></span>
          <span className="text-2xl font-extrabold tracking-tight">adoptify<span className="text-orange-600">.</span></span>
        </Link>
        <p className="mb-4 mt-12 text-[10px] font-bold tracking-[0.18em] text-stone-400">ESPACIO DE LA FUNDACIÓN</p>
        <Navigation />
        <div className="mt-auto rounded-2xl bg-orange-50 p-5">
          <Heart className="mb-3 text-orange-600" size={23} />
          <p className="font-semibold">Cada hogar cuenta.</p>
          <p className="mt-2 text-sm leading-6 text-stone-600">Gracias por darles una nueva oportunidad.</p>
        </div>
        <div className="mt-6 flex items-center gap-3 border-t border-stone-100 pt-6">
          <span className="flex size-10 shrink-0 items-center justify-center rounded-full bg-emerald-100 text-sm font-bold text-emerald-800">{initials}</span>
          <div className="min-w-0 flex-1"><p className="truncate text-sm font-semibold">{user?.full_name}</p><p className="truncate text-xs text-stone-500">{user?.email}</p></div>
          <button onClick={signOut} aria-label="Cerrar sesión" title="Cerrar sesión" className="rounded-lg p-2 text-stone-500 hover:bg-stone-100 hover:text-stone-900"><LogOut size={18} /></button>
        </div>
      </aside>
      <header className="flex min-h-20 items-center justify-between gap-3 border-b border-stone-200 bg-white px-5 sm:px-9">
        <div className="flex items-center gap-3">
          <button className="rounded-lg p-2 hover:bg-stone-100 lg:hidden" aria-label={menuOpen ? 'Cerrar navegación' : 'Abrir navegación'} aria-expanded={menuOpen} aria-controls="mobile-navigation" onClick={() => setMenuOpen(!menuOpen)}>
            {menuOpen ? <X size={22} /> : <Menu size={22} />}
          </button>
          <p className="text-sm text-stone-500"><span className="hidden sm:inline">Portal de fundaciones <ChevronRight className="mx-2 inline" size={13} /></span><span className="font-medium text-stone-800">{title}</span></p>
        </div>
        <span className="rounded-full border border-orange-200 bg-orange-50 px-3 py-1.5 text-xs font-medium text-orange-800">{isAnimalsPage || location.pathname === '/' ? 'Datos del backend' : 'Vista de ejemplo'}</span>
      </header>
      {menuOpen && <div id="mobile-navigation" className="border-b border-stone-200 bg-white p-4 lg:hidden"><Navigation onNavigate={() => setMenuOpen(false)} /><button onClick={signOut} className="mt-2 flex w-full items-center gap-3 rounded-xl px-4 py-3 text-sm font-medium text-stone-500 hover:bg-stone-50 hover:text-stone-900"><LogOut size={19} />Cerrar sesión</button></div>}
      <main id="contenido" className="mx-auto max-w-7xl px-5 py-8 sm:px-9 sm:py-10"><Outlet /></main>
      <footer className="mx-5 mt-8 flex flex-wrap justify-between gap-2 border-t border-stone-200 py-6 text-xs text-stone-500 sm:mx-9">
        <span>Adoptify · Conectamos vidas, creamos hogares.</span><span>Portal de fundaciones</span>
      </footer>
    </div>
  )
}

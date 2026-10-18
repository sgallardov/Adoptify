import { BrowserRouter, Route, Routes } from 'react-router'
import Layout from './components/Layout'
import Dashboard from './pages/Dashboard'
import Animals from './pages/Animals'
import AnimalDetail from './pages/AnimalDetail'
import Foundation from './pages/Foundation'
import NotFound from './pages/NotFound'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<Dashboard />} />
          <Route path="animales" element={<Animals />} />
          <Route path="animales/:id" element={<AnimalDetail />} />
          <Route path="fundacion" element={<Foundation />} />
          <Route path="*" element={<NotFound />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}

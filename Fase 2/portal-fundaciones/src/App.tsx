import { BrowserRouter, Route, Routes } from 'react-router'
import AuthProvider from './components/AuthProvider'
import RequireAuth from './components/RequireAuth'
import Layout from './components/Layout'
import Login from './pages/Login'
import UserHome from './pages/UserHome'
import Dashboard from './pages/Dashboard'
import Animals from './pages/Animals'
import AnimalDetail from './pages/AnimalDetail'
import Foundation from './pages/Foundation'
import NotFound from './pages/NotFound'

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="login" element={<Login />} />
          <Route element={<RequireAuth roles={['adopter']} />}>
            <Route path="usuario" element={<UserHome />} />
          </Route>
          <Route element={<RequireAuth roles={['foundation', 'admin']} />}>
            <Route element={<Layout />}>
              <Route index element={<Dashboard />} />
              <Route path="animales" element={<Animals />} />
              <Route path="animales/:id" element={<AnimalDetail />} />
              <Route path="fundacion" element={<Foundation />} />
              <Route path="*" element={<NotFound />} />
            </Route>
          </Route>
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  )
}

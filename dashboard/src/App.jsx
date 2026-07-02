import { useState, useEffect } from 'react'
import { supabase, ADMIN_EMAIL } from './supabaseClient'
import Login from './components/Login'
import AdminPanel from './components/AdminPanel'

export default function App() {
  const [session, setSession] = useState(undefined) // undefined = loading
  const [authError, setAuthError] = useState(null)
  const [devBypassed, setDevBypassed] = useState(false)

  useEffect(() => {
    // Check existing session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session)
    })

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session)
    })
    return () => subscription.unsubscribe()
  }, [])

  // ── Loading splash ──────────────────────────────────────────────
  if (session === undefined) {
    return (
      <div style={{ minHeight: '100vh', display: 'grid', placeItems: 'center' }}>
        <div className="spinner" style={{ width: 32, height: 32 }} />
      </div>
    )
  }

  // ── If bypassed locally ─────────────────────────────────────────
  if (devBypassed) {
    return (
      <AdminPanel 
        session={{ user: { email: ADMIN_EMAIL } }} 
        onSignOut={() => setDevBypassed(false)} 
      />
    )
  }

  // ── Guard: only the admin email may proceed ─────────────────────
  if (session && session.user.email !== ADMIN_EMAIL) {
    supabase.auth.signOut()
    return (
      <div className="login-wrap">
        <div className="login-card" style={{ gap: 16 }}>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: 40, marginBottom: 12 }}>🚫</div>
            <h2 style={{ color: 'var(--red)', marginBottom: 8 }}>Unauthorized</h2>
            <p style={{ fontSize: 13 }}>
              Your account (<strong style={{ color: 'var(--text-primary)' }}>{session.user.email}</strong>)
              is not authorized to access this admin panel.
            </p>
          </div>
          <button className="btn btn-ghost w-full" onClick={() => supabase.auth.signOut()}>
            Sign Out
          </button>
        </div>
      </div>
    )
  }

  if (!session) {
    return (
      <Login 
        onError={setAuthError} 
        externalError={authError} 
        onDevBypass={() => setDevBypassed(true)}
      />
    )
  }

  return <AdminPanel session={session} />
}

import { useState } from 'react'
import { supabase } from '../supabaseClient'
import { ShieldIcon } from './Icons'

export default function Login({ onError, externalError, onDevBypass }) {
  const [email, setEmail]       = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading]   = useState(false)
  const [error, setError]       = useState(externalError || null)

  async function handleLogin(e) {
    e.preventDefault()
    setLoading(true)
    setError(null)
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    setLoading(false)
    if (error) setError(error.message)
  }

  return (
    <div className="login-wrap">
      <form className="login-card" onSubmit={handleLogin}>
        {/* Saverites Logo */}
        <div className="login-logo">
          <img 
            src="/assets/logo.png" 
            alt="Saverites" 
            style={{ width: 44, height: 44, borderRadius: 10, objectFit: 'cover' }} 
          />
          <div className="login-logo-text">
            <h1 style={{ letterSpacing: '-0.02em', fontSize: '1.4rem' }}>Saverites</h1>
            <p style={{ fontSize: '11px', color: 'var(--text-muted)' }}>Admin Control Panel</p>
          </div>
        </div>

        {error && <div className="login-error">⚠️ &nbsp;{error}</div>}

        <div className="login-form-group">
          <label>Admin Email</label>
          <input
            className="input-field"
            type="email"
            placeholder="your@email.com"
            value={email}
            onChange={e => setEmail(e.target.value)}
            required
            autoFocus
          />
        </div>

        <div className="login-form-group">
          <label>Password</label>
          <input
            className="input-field"
            type="password"
            placeholder="••••••••"
            value={password}
            onChange={e => setPassword(e.target.value)}
            required
          />
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <button className="login-btn" type="submit" disabled={loading}>
            {loading ? 'Signing in…' : 'Sign In to Dashboard'}
          </button>
          
          <button 
            type="button" 
            className="btn btn-ghost w-full" 
            style={{ padding: '12px', justifyContent: 'center', gap: '8px' }}
            onClick={onDevBypass}
          >
            <ShieldIcon style={{ width: 15, height: 15 }} />
            Bypass Login (Dev Mode)
          </button>
        </div>

        <p style={{ textAlign: 'center', fontSize: 11.5, color: 'var(--text-muted)', marginTop: -2 }}>
          Restricted to authorised administrators only
        </p>
      </form>
    </div>
  )
}

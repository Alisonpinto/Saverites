import { useState, useEffect } from 'react'
import { supabase } from '../../supabaseClient'
import { SearchIcon, RefreshIcon, TrashIcon } from '../Icons'

export default function UsersTab() {
  const [users, setUsers]     = useState([])
  const [bans, setBans]       = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch]   = useState('')
  const [deleting, setDeleting] = useState(null) // user_id being deleted

  // Modal states for ban feature
  const [banningUser, setBanningUser] = useState(null)
  const [banDuration, setBanDuration] = useState('1d') // '1h', '1d', '3d', '7d', 'perm'

  useEffect(() => {
    load()
    
    // ── REALTIME: Subscribe to all profile and post database events ─────────
    const ch = supabase.channel('users_tab_realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => {
        loadSilent()
      })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'posts' }, () => {
        loadSilent()
      })
      .subscribe()
      
    return () => {
      supabase.removeChannel(ch)
    }
  }, [])

  async function load() {
    setLoading(true)
    const { data: profileData } = await supabase
      .from('profiles')
      .select('id,name,user_id,email,created_at,avatar_seed')
      .order('created_at', { ascending: false })
    
    const { data: banData } = await supabase
      .from('posts')
      .select('id,title,body')
      .eq('type', 'ban')

    setUsers(profileData ?? [])
    setBans(banData ?? [])
    setLoading(false)
  }

  // Load silently on realtime update to avoid flickering spinners
  async function loadSilent() {
    const { data: profileData } = await supabase
      .from('profiles')
      .select('id,name,user_id,email,created_at,avatar_seed')
      .order('created_at', { ascending: false })
    
    const { data: banData } = await supabase
      .from('posts')
      .select('id,title,body')
      .eq('type', 'ban')

    if (profileData) setUsers(profileData)
    if (banData) setBans(banData)
  }

  async function deleteUser(user) {
    if (!window.confirm(`Delete user "${user.name}" (@${user.user_id})?\nThis removes their profile from the database.`)) return
    setDeleting(user.user_id)
    try {
      await supabase.from('profiles').delete().eq('id', user.id)
    } catch (e) {
      alert('Error deleting user: ' + e.message)
    }
    setDeleting(null)
  }

  function getBanStatus(userId) {
    const ban = bans.find(b => b.title === userId)
    if (!ban) return null
    if (ban.body === 'permanent') return { type: 'permanent', expiry: null }
    const expiry = new Date(ban.body)
    if (expiry > new Date()) {
      return { type: 'temporary', expiry }
    }
    return null; // Expired
  }

  async function executeBan() {
    if (!banningUser) return
    let expiryStr = 'permanent'
    if (banDuration !== 'perm') {
      const now = new Date()
      if (banDuration === '1h') now.setHours(now.getHours() + 1)
      else if (banDuration === '1d') now.setDate(now.getDate() + 1)
      else if (banDuration === '3d') now.setDate(now.getDate() + 3)
      else if (banDuration === '7d') now.setDate(now.getDate() + 7)
      expiryStr = now.toISOString()
    }
    
    try {
      const { data: { user } } = await supabase.auth.getUser()
      let adminUserId = 'saverites2026'
      if (user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('user_id')
          .eq('id', user.id)
          .maybeSingle()
        if (profile) adminUserId = profile.user_id
      }
      
      // Delete any existing ban record first to avoid duplicate primary key errors
      await supabase.from('posts').delete().eq('id', `ban-${banningUser.user_id}`)

      await supabase.from('posts').insert({
        id: `ban-${banningUser.user_id}`,
        user_id: adminUserId,
        title: banningUser.user_id, // Who is banned
        body: expiryStr, // Expiry timestamp or 'permanent'
        type: 'ban',
        saved_in_profile: false,
        is_locked: false,
      })
      setBanningUser(null)
    } catch (e) {
      alert('Error banning user: ' + e.message)
    }
  }

  async function unbanUser(userId) {
    if (!window.confirm(`Lift the ban for @${userId}?`)) return
    try {
      await supabase.from('posts').delete().eq('id', `ban-${userId}`)
    } catch (e) {
      alert('Error unbanning user: ' + e.message)
    }
  }

  const filtered = users.filter(u => {
    const q = search.toLowerCase()
    return (u.name?.toLowerCase().includes(q) || u.user_id?.toLowerCase().includes(q) || u.email?.toLowerCase().includes(q))
  })

  return (
    <>
      {/* Search + stats row */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
        <div style={{ position: 'relative', width: '100%', maxWidth: 320 }}>
          <SearchIcon style={{ position: 'absolute', left: 12, top: 15, color: 'var(--text-muted)', width: 15, height: 15 }} />
          <input
            className="input-field"
            style={{ paddingLeft: 36 }}
            placeholder="Search by name, user ID or email…"
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
        <div className="badge badge-blue">{filtered.length} users</div>
        <div className="live-chip" style={{ marginLeft: 'auto' }}>
          <span className="pulse pulse-green" />Realtime
        </div>
      </div>

      <div className="panel">
        <div className="panel-header">
          <h2>All Users</h2>
          <button className="btn btn-ghost btn-sm" style={{ gap: 6 }} onClick={load}>
            <RefreshIcon style={{ width: 12, height: 12 }} />
            Refresh
          </button>
        </div>
        {loading ? (
          <div style={{ display: 'flex', justifyContent: 'center', padding: 40 }}><div className="spinner" /></div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>User ID</th>
                <th>Email</th>
                <th>Joined</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 && (
                <tr><td colSpan={5} style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '32px' }}>No users found</td></tr>
              )}
              {filtered.map(u => {
                const ban = getBanStatus(u.user_id)
                return (
                  <tr key={u.id}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <div style={{
                          width: 32, height: 32, borderRadius: '50%',
                          background: 'linear-gradient(135deg,var(--accent),var(--accent-2))',
                          display: 'grid', placeItems: 'center', fontSize: 13, fontWeight: 700, flexShrink: 0
                        }}>
                          {(u.name || 'U')[0].toUpperCase()}
                        </div>
                        <span style={{ fontWeight: 600 }}>{u.name || '—'}</span>
                      </div>
                    </td>
                    <td>
                      <span style={{ color: 'var(--text-muted)' }}>@{u.user_id}</span>
                      {ban && (
                        <div style={{ color: 'var(--red)', fontSize: 11, marginTop: 4, display: 'flex', alignItems: 'center', gap: 4 }}>
                          🚫 {ban.type === 'permanent' ? 'Banned permanently' : `Banned until ${new Date(ban.expiry).toLocaleString()}`}
                        </div>
                      )}
                    </td>
                    <td className="truncate text-muted text-sm">{u.email}</td>
                    <td className="text-muted text-sm">
                      {u.created_at ? new Date(u.created_at).toLocaleDateString() : '—'}
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: 8 }}>
                        {ban ? (
                          <button
                            className="btn btn-ghost btn-sm"
                            onClick={() => unbanUser(u.user_id)}
                            style={{ borderColor: 'rgba(46,204,113,0.3)', color: 'var(--green)' }}
                          >
                            Lift Ban
                          </button>
                        ) : (
                          <button
                            className="btn btn-ghost btn-sm"
                            onClick={() => setBanningUser(u)}
                            style={{ borderColor: 'rgba(245,158,11,0.3)', color: 'var(--amber)' }}
                          >
                            Ban
                          </button>
                        )}
                        <button
                          className="btn btn-danger btn-sm"
                          style={{ gap: 6 }}
                          disabled={deleting === u.user_id}
                          onClick={() => deleteUser(u)}
                        >
                          <TrashIcon style={{ width: 12, height: 12 }} />
                          {deleting === u.user_id ? 'Deleting…' : 'Delete'}
                        </button>
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Ban Duration Selection Modal */}
      {banningUser && (
        <div className="modal-backdrop" onClick={() => setBanningUser(null)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-title" style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <span>🚫 Ban User</span>
              <span style={{ color: 'var(--accent)', fontWeight: 600 }}>@{banningUser.user_id}</span>
            </div>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              <p style={{ fontSize: 13, color: 'var(--text-secondary)' }}>
                Select the duration for which this user should be banned from logging in or using the app.
              </p>
              
              <div>
                <label style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', display: 'block', marginBottom: 8 }}>
                  Ban Duration
                </label>
                <select
                  className="input-field"
                  value={banDuration}
                  onChange={e => setBanDuration(e.target.value)}
                >
                  <option value="1h">1 Hour</option>
                  <option value="1d">1 Day</option>
                  <option value="3d">3 Days</option>
                  <option value="7d">7 Days</option>
                  <option value="perm">Permanent</option>
                </select>
              </div>
            </div>

            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={() => setBanningUser(null)}>
                Cancel
              </button>
              <button className="btn btn-primary" style={{ backgroundColor: 'var(--red)', color: 'white' }} onClick={executeBan}>
                Confirm Ban
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}

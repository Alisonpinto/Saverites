import { useState, useEffect } from 'react'
import { supabase } from '../../supabaseClient'
import { BellIcon, SendIcon, CheckIcon } from '../Icons'

export default function NotifTab() {
  const [users, setUsers]       = useState([])
  const [toUserId, setToUserId] = useState('')
  const [message, setMessage]   = useState('')
  const [sending, setSending]   = useState(false)
  const [sent, setSent]         = useState(false)
  const [recentNotifs, setRecentNotifs] = useState([])
  const [adminProfile, setAdminProfile] = useState(null)

  useEffect(() => {
    loadUsers()
    loadNotifs()

    // Fetch logged in admin profile to satisfy RLS policy
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) {
        supabase
          .from('profiles')
          .select('user_id')
          .eq('id', user.id)
          .maybeSingle()
          .then(({ data }) => {
            if (data) setAdminProfile(data)
          })
      }
    })
    
    // ── REALTIME: Live streaming notifications ────────────────────
    const ch = supabase.channel('notif_tab_realtime')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications' }, () => {
        loadNotifsSilent()
      })
      .subscribe()

    return () => {
      supabase.removeChannel(ch)
    }
  }, [])

  async function loadUsers() {
    const { data } = await supabase.from('profiles').select('id,name,user_id').order('name')
    setUsers(data ?? [])
  }

  async function loadNotifs() {
    const { data } = await supabase
      .from('notifications')
      .select('id,to_user_id,from_user_id,preview_text,action_type,created_at,is_read')
      .order('created_at', { ascending: false })
      .limit(50)
    setRecentNotifs(data ?? [])
  }

  async function loadNotifsSilent() {
    const { data } = await supabase
      .from('notifications')
      .select('id,to_user_id,from_user_id,preview_text,action_type,created_at,is_read')
      .order('created_at', { ascending: false })
      .limit(50)
    if (data) setRecentNotifs(data)
  }

  async function sendNotification(e) {
    e.preventDefault()
    if (!toUserId || !message.trim()) return
    setSending(true)
    setSent(false)
    try {
      const fromUserId = adminProfile?.user_id ?? 'saverites2026'
      const notifId = 'admin-' + Date.now() + '-' + Math.floor(Math.random() * 1000)
      
      const { error } = await supabase.from('notifications').insert({
        id:            notifId,
        to_user_id:    toUserId,
        from_user_id:  fromUserId,
        avatar_seed:   'admin',
        avatar_initial:'A',
        avatar_color:  4284955319,
        username:      'Admin',
        preview_text:  message.trim(),
        action_type:   'admin_message',
        is_read:       false,
      })
      
      if (error) {
        throw error;
      }
      
      setMessage('')
      setSent(true)
      setTimeout(() => setSent(false), 3000)
    } catch (err) {
      alert('Error: ' + err.message)
    }
    setSending(false)
  }

  return (
    <>
      {/* Send notification panel */}
      <div className="panel" style={{ marginBottom: 24, maxWidth: 560 }}>
        <div className="panel-header" style={{ gap: '8px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <BellIcon style={{ width: 16, height: 16, color: 'var(--accent)' }} />
            <h2>Send Admin Notification</h2>
          </div>
        </div>
        <div className="panel-body">
          <form onSubmit={sendNotification} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <div>
              <label style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', display: 'block', marginBottom: 8 }}>
                Recipient User
              </label>
              <select
                className="input-field"
                value={toUserId}
                onChange={e => setToUserId(e.target.value)}
                required
              >
                <option value="">— Select a user —</option>
                {users.map(u => (
                  <option key={u.id} value={u.user_id}>{u.name} (@{u.user_id})</option>
                ))}
              </select>
            </div>
            <div>
              <label style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', display: 'block', marginBottom: 8 }}>
                Message
              </label>
              <textarea
                className="input-field"
                rows={3}
                placeholder="Write your admin notification message…"
                value={message}
                onChange={e => setMessage(e.target.value)}
                style={{ resize: 'vertical', fontFamily: 'inherit' }}
                required
              />
            </div>
            <button className="btn btn-primary" style={{ gap: '8px' }} type="submit" disabled={sending || !toUserId || !message.trim()}>
              <SendIcon style={{ width: 14, height: 14 }} />
              {sending ? 'Sending…' : 'Send Notification'}
            </button>
            {sent && (
              <div style={{ color: 'var(--green)', fontSize: 13, display: 'flex', alignItems: 'center', gap: 6 }}>
                <CheckIcon style={{ width: 15, height: 15 }} />
                Notification sent successfully!
              </div>
            )}
          </form>
        </div>
      </div>

      {/* Recent notifications */}
      <div className="panel">
        <div className="panel-header">
          <h2>Recent Notifications</h2>
          <div className="live-chip"><span className="pulse pulse-green" />Realtime</div>
        </div>
        <table className="data-table">
          <thead>
            <tr>
              <th>To</th>
              <th>From</th>
              <th>Message</th>
              <th>Type</th>
              <th>Read</th>
              <th>Date</th>
            </tr>
          </thead>
          <tbody>
            {recentNotifs.length === 0 && (
              <tr><td colSpan={6} style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '32px' }}>No notifications yet</td></tr>
            )}
            {recentNotifs.map(n => (
              <tr key={n.id}>
                <td className="text-sm text-muted">{n.to_user_id?.slice(0, 12) ?? '—'}</td>
                <td className="text-sm">{n.from_user_id?.slice(0, 12) ?? '—'}</td>
                <td className="truncate text-sm text-muted">{n.preview_text}</td>
                <td><span className="badge badge-blue" style={{ fontSize: 10 }}>{n.action_type}</span></td>
                <td><span className={`badge ${n.is_read ? 'badge-green' : 'badge-amber'}`}>{n.is_read ? 'Read' : 'Unread'}</span></td>
                <td className="text-sm text-muted">{n.created_at ? new Date(n.created_at).toLocaleString() : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}

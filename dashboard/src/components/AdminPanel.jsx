import { useState } from 'react'
import { supabase } from '../supabaseClient'
import OverviewTab  from './tabs/OverviewTab'
import UsersTab     from './tabs/UsersTab'
import PostsTab     from './tabs/PostsTab'
import HealthTab    from './tabs/HealthTab'
import NotifTab     from './tabs/NotifTab'
import { ChartIcon, ActivityIcon, UsersIcon, DocumentIcon, BellIcon, LogoutIcon } from './Icons'

const TABS = [
  { id: 'overview',  label: 'Overview',       icon: ChartIcon },
  { id: 'health',    label: 'App Health',      icon: ActivityIcon },
  { id: 'users',     label: 'Users',           icon: UsersIcon },
  { id: 'posts',     label: 'Posts',           icon: DocumentIcon },
  { id: 'notifs',    label: 'Notifications',   icon: BellIcon },
]

export default function AdminPanel({ session, onSignOut }) {
  const [tab, setTab] = useState('overview')

  const handleSignOut = async () => {
    if (onSignOut) {
      onSignOut()
    } else {
      await supabase.auth.signOut()
    }
  }

  const initial = (session.user.email || 'A')[0].toUpperCase()

  return (
    <div className="app-shell">
      {/* ── Sidebar ───────────────────────────────────────────── */}
      <aside className="sidebar">
        <div className="sidebar-logo">
          <img 
            src="/assets/logo.png" 
            alt="Saverites" 
            style={{ width: 32, height: 32, borderRadius: 8, objectFit: 'cover' }} 
            onError={(e) => {
              // Fallback to text logo if image fails to load
              e.target.style.display = 'none'
            }}
          />
          <span>Saverites Admin</span>
        </div>

        <div className="nav-section-label">Navigation</div>
        {TABS.map(t => {
          const IconComponent = t.icon
          return (
            <div
              key={t.id}
              className={`nav-item ${tab === t.id ? 'active' : ''}`}
              onClick={() => setTab(t.id)}
            >
              <IconComponent className="nav-icon" style={{ width: 17, height: 17 }} />
              {t.label}
            </div>
          )
        })}

        <div className="sidebar-footer">
          <div className="nav-item" onClick={handleSignOut} style={{ color: 'var(--red)' }}>
            <LogoutIcon className="nav-icon" style={{ width: 17, height: 17 }} />
            Sign Out
          </div>
        </div>
      </aside>

      {/* ── Main ─────────────────────────────────────────────── */}
      <div className="main-content">
        {/* Top bar */}
        <div className="top-bar">
          <h1>{TABS.find(t => t.id === tab)?.label}</h1>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div className="live-chip">
              <span className="pulse pulse-green" />
              LIVE
            </div>
            <div className="admin-badge">
              <div className="admin-avatar">{initial}</div>
              {session.user.email}
            </div>
          </div>
        </div>

        {/* Tab content */}
        <div className="page-content">
          {tab === 'overview' && <OverviewTab />}
          {tab === 'health'   && <HealthTab />}
          {tab === 'users'    && <UsersTab />}
          {tab === 'posts'    && <PostsTab />}
          {tab === 'notifs'   && <NotifTab />}
        </div>
      </div>
    </div>
  )
}

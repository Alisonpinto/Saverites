import { useState, useEffect } from 'react'
import { supabase } from '../../supabaseClient'
import { UsersIcon, DocumentIcon, BellIcon, ChartIcon } from '../Icons'
import {
  AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid
} from 'recharts'

export default function OverviewTab() {
  const [stats, setStats]         = useState({ users: 0, posts: 0, notifs: 0, feedback: 0 })
  const [recentUsers, setRecentUsers] = useState([])
  const [signupChart, setSignupChart] = useState([])
  const [loading, setLoading]     = useState(true)

  useEffect(() => {
    loadAll()
    // Realtime subscription on profiles (new users) & posts
    const ch = supabase.channel('overview_profiles')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, () => loadSilent())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'posts' }, () => loadSilent())
      .subscribe()
    return () => supabase.removeChannel(ch)
  }, [])

  async function loadAll() {
    try {
      setLoading(true)
      const [
        { count: userCount },
        { count: postCount },
        { count: notifCount },
        { count: fbCount },
        { data: users },
      ] = await Promise.all([
        supabase.from('profiles').select('*', { count: 'exact', head: true }),
        supabase.from('posts').select('*', { count: 'exact', head: true }).neq('type', 'ban'),
        supabase.from('notifications').select('*', { count: 'exact', head: true }),
        supabase.from('feedback').select('*', { count: 'exact', head: true }),
        supabase.from('profiles').select('name,user_id,created_at').order('created_at', { ascending: false }).limit(5),
      ])
      setStats({ users: userCount ?? 0, posts: postCount ?? 0, notifs: notifCount ?? 0, feedback: fbCount ?? 0 })
      setRecentUsers(users ?? [])

      // Build last-7-day signup chart from recent profiles
      const { data: allUsers } = await supabase
        .from('profiles')
        .select('created_at')
        .gte('created_at', new Date(Date.now() - 7 * 86400000).toISOString())
      buildChart(allUsers ?? [])
    } catch (e) {
      console.error(e)
    } finally {
      setLoading(false)
    }
  }

  async function loadSilent() {
    try {
      const [
        { count: userCount },
        { count: postCount },
        { count: notifCount },
        { count: fbCount },
        { data: users },
      ] = await Promise.all([
        supabase.from('profiles').select('*', { count: 'exact', head: true }),
        supabase.from('posts').select('*', { count: 'exact', head: true }).neq('type', 'ban'),
        supabase.from('notifications').select('*', { count: 'exact', head: true }),
        supabase.from('feedback').select('*', { count: 'exact', head: true }),
        supabase.from('profiles').select('name,user_id,created_at').order('created_at', { ascending: false }).limit(5),
      ])
      setStats({ users: userCount ?? 0, posts: postCount ?? 0, notifs: notifCount ?? 0, feedback: fbCount ?? 0 })
      setRecentUsers(users ?? [])

      const { data: allUsers } = await supabase
        .from('profiles')
        .select('created_at')
        .gte('created_at', new Date(Date.now() - 7 * 86400000).toISOString())
      buildChart(allUsers ?? [])
    } catch (e) {
      console.error(e)
    }
  }

  function buildChart(users) {
    const days = []
    for (let i = 6; i >= 0; i--) {
      const d = new Date(Date.now() - i * 86400000)
      const label = d.toLocaleDateString('en', { weekday: 'short' })
      const count = users.filter(u => {
        const ud = new Date(u.created_at)
        return ud.toDateString() === d.toDateString()
      }).length
      days.push({ day: label, signups: count })
    }
    setSignupChart(days)
  }

  if (loading) {
    return <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 60 }}><div className="spinner" /></div>
  }

  return (
    <>
      {/* Stat cards */}
      <div className="stats-grid">
        <StatCard label="Total Users"          value={stats.users}    icon={UsersIcon} color="var(--accent)"  sub="Registered accounts" />
        <StatCard label="Total Posts"          value={stats.posts}    icon={DocumentIcon} color="var(--accent-2)" sub="All-time posts" />
        <StatCard label="Notifications Sent"   value={stats.notifs}   icon={BellIcon} color="var(--green)"   sub="All-time" />
        <StatCard label="Feedback"             value={stats.feedback} icon={ChartIcon} color="var(--amber)"   sub="User submissions" />
      </div>

      {/* Signup chart */}
      <div className="panel" style={{ marginBottom: 20 }}>
        <div className="panel-header">
          <h2>New Signups (Last 7 Days)</h2>
          <div className="live-chip"><span className="pulse pulse-green" />Live</div>
        </div>
        <div className="panel-body">
          <div className="chart-wrap">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={signupChart}>
                <defs>
                  <linearGradient id="sg" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%"  stopColor="#6b9bf7" stopOpacity={0.25} />
                    <stop offset="95%" stopColor="#6b9bf7" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" />
                <XAxis dataKey="day" tick={{ fill: '#555566', fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: '#555566', fontSize: 11 }} axisLine={false} tickLine={false} allowDecimals={false} />
                <Tooltip
                  contentStyle={{ background: '#14141a', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, fontSize: 12 }}
                  labelStyle={{ color: '#f0f0f8' }}
                  itemStyle={{ color: '#6b9bf7' }}
                />
                <Area type="monotone" dataKey="signups" stroke="#6b9bf7" strokeWidth={2} fill="url(#sg)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Recent users */}
      <div className="panel">
        <div className="panel-header">
          <h2>Recent Users</h2>
        </div>
        <table className="data-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>User ID</th>
              <th>Joined</th>
            </tr>
          </thead>
          <tbody>
            {recentUsers.length === 0 && (
              <tr><td colSpan={3} style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '24px' }}>No users yet</td></tr>
            )}
            {recentUsers.map((u, i) => (
              <tr key={i}>
                <td><span className="font-bold">{u.name || '—'}</span></td>
                <td><span className="text-muted">@{u.user_id}</span></td>
                <td className="text-muted text-sm">{u.created_at ? new Date(u.created_at).toLocaleDateString() : '—'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}

function StatCard({ label, value, icon: IconComponent, color, sub }) {
  return (
    <div className="stat-card">
      <div className="stat-icon" style={{ opacity: 0.15, right: 20, top: 20 }}>
        <IconComponent style={{ width: 36, height: 36 }} />
      </div>
      <div className="stat-label">{label}</div>
      <div className="stat-value" style={{ color }}>{value.toLocaleString()}</div>
      <div className="stat-sub">{sub}</div>
    </div>
  )
}

import { useState, useEffect, useRef } from 'react'
import { supabase } from '../../supabaseClient'
import { ActivityIcon, RefreshIcon, AlertIcon } from '../Icons'

// Event severity levels
const SEV = {
  info:    { cls: 'badge-blue',  label: 'INFO'   },
  warn:    { cls: 'badge-amber', label: 'WARN'   },
  danger:  { cls: 'badge-red',   label: 'THREAT' },
  success: { cls: 'badge-green', label: 'OK'     },
}

export default function HealthTab() {
  const [events, setEvents]     = useState([])
  const [metrics, setMetrics]   = useState({
    dbPing: null,
    totalUsers: 0,
    activeSessions: 0,
    failedLogins: 0,
    suspiciousIPs: 0,
  })
  const [pingHistory, setPingHistory] = useState([])
  const logRef = useRef(null)

  useEffect(() => {
    measure()
    const interval = setInterval(measure, 10000)

    // Realtime monitoring — watch for unusual bursts on database tables
    const ch = supabase.channel('health_monitor_system')
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notifications' }, (payload) => {
        addEvent('info', 'Notification', `New notification inserted (id: ${payload.new?.id?.slice(0,8) ?? '?'}...)`)
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'profiles' }, (payload) => {
        addEvent('success', 'New User', `"${payload.new?.name || payload.new?.user_id}" registered`)
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'profiles' }, (payload) => {
        addEvent('warn', 'Account Deleted', `User ID "${payload.old?.user_id}" was deleted`)
      })
      .on('postgres_changes', { event: 'DELETE', schema: 'public', table: 'posts' }, (payload) => {
        addEvent('warn', 'Post Deleted', `Post "${payload.old?.id?.slice(0,8) ?? '?'}..." was removed`)
      })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'posts' }, (payload) => {
        addEvent('info', 'New Post', `User "${payload.new?.user_id}" created a post`)
      })
      .subscribe()

    addEvent('success', 'Health Monitor', 'Realtime monitoring connected')

    return () => {
      clearInterval(interval)
      supabase.removeChannel(ch)
    }
  }, [])

  // Scroll log to bottom on new event
  useEffect(() => {
    if (logRef.current) logRef.current.scrollTop = logRef.current.scrollHeight
  }, [events])

  async function measure() {
    const start = performance.now()
    try {
      const { count } = await supabase
        .from('profiles')
        .select('*', { count: 'exact', head: true })
      const ping = Math.round(performance.now() - start)
      setPingHistory(h => [...h.slice(-19), ping])
      setMetrics(m => ({ ...m, dbPing: ping, totalUsers: count ?? 0 }))

      if (ping > 1200) {
        addEvent('warn', 'Slow DB', `Response time ${ping}ms — above threshold`)
      } else if (ping > 2500) {
        addEvent('danger', 'DB Timeout', `Response time ${ping}ms — possible overload`)
      }
    } catch (err) {
      addEvent('danger', 'DB Error', err.message)
    }
  }

  function addEvent(sev, type, detail) {
    const now = new Date()
    const time = now.toLocaleTimeString('en', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
    setEvents(prev => [{ sev, type, detail, time, id: Date.now() + Math.random() }, ...prev].slice(0, 80))
  }

  const avgPing = pingHistory.length
    ? Math.round(pingHistory.reduce((a, b) => a + b, 0) / pingHistory.length)
    : null

  const pingStatus = metrics.dbPing === null
    ? { label: 'Checking…', color: 'var(--text-muted)', pulse: 'pulse-amber' }
    : metrics.dbPing < 600
      ? { label: 'Healthy',  color: 'var(--green)', pulse: 'pulse-green' }
      : metrics.dbPing < 1500
        ? { label: 'Slow',   color: 'var(--amber)', pulse: 'pulse-amber' }
        : { label: 'Critical', color: 'var(--red)', pulse: 'pulse-red'   }

  return (
    <>
      {/* Health metric cards */}
      <div className="health-grid">
        <HealthCard
          title="DB Response"
          value={metrics.dbPing !== null ? `${metrics.dbPing}ms` : '—'}
          status={<><span className={`pulse ${pingStatus.pulse}`} />{pingStatus.label}</>}
          statusColor={pingStatus.color}
        />
        <HealthCard
          title="Avg DB Ping (20 samples)"
          value={avgPing !== null ? `${avgPing}ms` : '—'}
          status={<><span className="pulse pulse-blue" style={{ background: 'var(--accent)' }} />Sampled every 10s</>}
          statusColor="var(--accent)"
        />
        <HealthCard
          title="Total Users"
          value={metrics.totalUsers.toLocaleString()}
          status={<><span className="pulse pulse-green" />Live from DB</>}
          statusColor="var(--green)"
        />
        <HealthCard
          title="Realtime Status"
          value="Connected"
          status={<><span className="pulse pulse-green" />Supabase Realtime</>}
          statusColor="var(--green)"
        />
        <HealthCard
          title="Ping Trend"
          value={
            pingHistory.length > 1
              ? (pingHistory[pingHistory.length-1] < pingHistory[0] ? 'Improving' : 'Rising')
              : 'Gathering…'
          }
          status={<><span className="pulse pulse-amber" />{pingHistory.length} samples</>}
          statusColor="var(--amber)"
        />
        <HealthCard
          title="Auth Provider"
          value="Supabase Auth"
          status={<><span className="pulse pulse-green" />Operational</>}
          statusColor="var(--green)"
        />
      </div>

      {/* Ping bar graph */}
      {pingHistory.length > 1 && (
        <div className="panel" style={{ marginBottom: 20 }}>
          <div className="panel-header">
            <h2>DB Response Trend (last {pingHistory.length} polls)</h2>
            <div className="live-chip"><span className="pulse pulse-green" />Updates every 10s</div>
          </div>
          <div className="panel-body">
            <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 80 }}>
              {pingHistory.map((p, i) => {
                const maxP = Math.max(...pingHistory, 1)
                const h = Math.max(4, Math.round((p / maxP) * 72))
                const col = p < 600 ? 'var(--green)' : p < 1500 ? 'var(--amber)' : 'var(--red)'
                return (
                  <div key={i} title={`${p}ms`}
                    style={{
                      flex: 1, height: h, background: col, borderRadius: 3,
                      opacity: 0.7 + (i / pingHistory.length) * 0.3,
                      transition: 'height 0.3s ease',
                    }}
                  />
                )
              })}
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6, fontSize: 11, color: 'var(--text-muted)' }}>
              <span>oldest</span>
              <span>latest ({metrics.dbPing}ms)</span>
            </div>
          </div>
        </div>
      )}

      {/* Realtime event log */}
      <div className="panel">
        <div className="panel-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <ActivityIcon style={{ width: 16, height: 16, color: 'var(--red)' }} />
            <h2>Live Event Log</h2>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="btn btn-ghost btn-sm" onClick={() => setEvents([])}>Clear</button>
            <div className="live-chip"><span className="pulse pulse-green" />Realtime</div>
          </div>
        </div>
        <div className="panel-body" style={{ padding: '14px 18px' }}>
          {events.length === 0 ? (
            <div className="empty-state">
              <AlertIcon style={{ width: 32, height: 32, color: 'var(--text-muted)' }} />
              <p>No events yet. Monitoring is active…</p>
            </div>
          ) : (
            <div className="event-log" ref={logRef} style={{ maxHeight: 420 }}>
              {events.map(ev => (
                <div key={ev.id} className="event-row">
                  <span className="event-time">{ev.time}</span>
                  <span className={`badge ${SEV[ev.sev].cls} event-type`} style={{ fontSize: 10 }}>
                    {SEV[ev.sev].label}
                  </span>
                  <span className="event-type" style={{ minWidth: 120, color: 'var(--text-primary)', fontWeight: 600 }}>
                    {ev.type}
                  </span>
                  <span className="event-detail">{ev.detail}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </>
  )
}

function HealthCard({ title, value, status, statusColor }) {
  return (
    <div className="health-card">
      <div className="health-title">{title}</div>
      <div className="health-value">{value}</div>
      <div className="health-status" style={{ color: statusColor }}>{status}</div>
    </div>
  )
}

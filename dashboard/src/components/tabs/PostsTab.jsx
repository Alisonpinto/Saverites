import { useState, useEffect } from 'react'
import { supabase, anonSupabase } from '../../supabaseClient'
import { SearchIcon, RefreshIcon, TrashIcon, ShieldIcon } from '../Icons'

export default function PostsTab() {
  const [posts, setPosts]     = useState([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch]   = useState('')
  const [deleting, setDeleting] = useState(null)
  const [viewingPost, setViewingPost] = useState(null)

  useEffect(() => {
    load()

    // ── REALTIME: Subscribe to post changes ──────────────────────
    const ch = supabase.channel('posts_tab_realtime')
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
    const { data } = await supabase
      .from('posts')
      .select('id,user_id,title,body,created_at,image_url,video_url,file_url,saved_in_profile,type')
      .neq('type', 'ban')
      .order('created_at', { ascending: false })
      .limit(200)
    setPosts(data ?? [])
    setLoading(false)
  }

  async function loadSilent() {
    const { data } = await supabase
      .from('posts')
      .select('id,user_id,title,body,created_at,image_url,video_url,file_url,saved_in_profile,type')
      .neq('type', 'ban')
      .order('created_at', { ascending: false })
      .limit(200)
    if (data) setPosts(data)
  }

  async function deletePost(post) {
    if (!window.confirm(`Delete post by @${post.user_id}?\n"${(post.body || post.title || '').slice(0, 80)}"`)) return
    setDeleting(post.id)
    try {
      await anonSupabase.from('posts').delete().eq('id', post.id)
    } catch (e) {
      alert('Error: ' + e.message)
    }
    setDeleting(null)
  }

  const filtered = posts.filter(p => {
    const q = search.toLowerCase()
    return (
      p.user_id?.toLowerCase().includes(q) ||
      p.title?.toLowerCase().includes(q) ||
      p.body?.toLowerCase().includes(q)
    )
  })

  return (
    <>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
        <div style={{ position: 'relative', width: '100%', maxWidth: 340 }}>
          <SearchIcon style={{ position: 'absolute', left: 12, top: 15, color: 'var(--text-muted)', width: 15, height: 15 }} />
          <input
            className="input-field"
            style={{ paddingLeft: 36 }}
            placeholder="Search by user, title or content…"
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
        <div className="badge badge-blue">{filtered.length} posts</div>
        <div className="live-chip" style={{ marginLeft: 'auto' }}>
          <span className="pulse pulse-green" />Realtime
        </div>
      </div>

      <div className="panel">
        <div className="panel-header">
          <h2>All Posts</h2>
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
                <th>User</th>
                <th>Content Preview (Click to View)</th>
                <th>Media</th>
                <th>Visibility</th>
                <th>Posted</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 && (
                <tr><td colSpan={6} style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '32px' }}>No posts found</td></tr>
              )}
              {filtered.map(p => (
                <tr key={p.id}>
                  <td>
                    <span style={{ color: 'var(--accent)', fontWeight: 600 }}>@{p.user_id}</span>
                  </td>
                  <td 
                    onClick={() => setViewingPost(p)}
                    style={{ cursor: 'pointer' }}
                    title="Click to view full post with media"
                  >
                    <div style={{ display: 'flex', flexDirection: 'column' }}>
                      {p.title && (
                        <span style={{ color: 'var(--text-primary)', fontWeight: 600, fontSize: 13, marginBottom: 2 }}>
                          {p.title}
                        </span>
                      )}
                      <span style={{ color: 'var(--text-secondary)', fontSize: 12 }} className="truncate">
                        {(p.body || '').slice(0, 80)}{(p.body?.length > 80) ? '…' : ''}
                      </span>
                    </div>
                  </td>
                  <td 
                    onClick={() => setViewingPost(p)}
                    style={{ cursor: 'pointer' }}
                  >
                    {p.image_url ? (
                      <img 
                        src={p.image_url} 
                        alt="" 
                        style={{ width: 40, height: 40, objectFit: 'cover', borderRadius: 6, border: '1px solid var(--border)' }} 
                        onError={(e) => {
                          e.target.src = '/assets/app_logo_square_dark.png'
                        }}
                      />
                    ) : p.video_url ? (
                      <div style={{
                        width: 40, height: 40, borderRadius: 6, background: 'var(--bg-input)',
                        display: 'grid', placeItems: 'center', border: '1px solid var(--border)', fontSize: 16
                      }}>
                        📹
                      </div>
                    ) : p.file_url ? (
                      <div style={{
                        width: 40, height: 40, borderRadius: 6, background: 'var(--bg-input)',
                        display: 'grid', placeItems: 'center', border: '1px solid var(--border)', fontSize: 16
                      }}>
                        📎
                      </div>
                    ) : (
                      <span className="text-muted text-sm">none</span>
                    )}
                  </td>
                  <td>
                    <span className={`badge ${p.saved_in_profile ? 'badge-amber' : 'badge-green'}`} style={{ gap: '4px' }}>
                      {p.saved_in_profile ? 'Private' : 'Public'}
                    </span>
                  </td>
                  <td className="text-muted text-sm">
                    {p.created_at ? new Date(p.created_at).toLocaleDateString() : '—'}
                  </td>
                  <td>
                    <button
                      className="btn btn-danger btn-sm"
                      style={{ gap: 6 }}
                      disabled={deleting === p.id}
                      onClick={() => deletePost(p)}
                    >
                      <TrashIcon style={{ width: 12, height: 12 }} />
                      {deleting === p.id ? 'Deleting…' : 'Delete'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Premium Full Post Detail Viewer Modal */}
      {viewingPost && (
        <div className="modal-backdrop" onClick={() => setViewingPost(null)}>
          <div className="modal" style={{ maxWidth: '600px', width: '90%', maxHeight: '85vh', overflowY: 'auto' }} onClick={e => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <span className="badge badge-blue">@{viewingPost.user_id}</span>
                <span className={`badge ${viewingPost.saved_in_profile ? 'badge-amber' : 'badge-green'}`}>
                  {viewingPost.saved_in_profile ? 'Private' : 'Public'}
                </span>
              </div>
              <button 
                className="btn btn-ghost" 
                onClick={() => setViewingPost(null)}
                style={{ padding: '4px 8px', minWidth: 'auto', border: 'none' }}
              >
                ✕
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
              {viewingPost.title && (
                <h2 style={{ fontSize: '1.4rem', fontWeight: 700, color: 'var(--text-primary)', margin: 0 }}>
                  {viewingPost.title}
                </h2>
              )}

              {viewingPost.body && (
                <div>
                  <label style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', display: 'block', marginBottom: 6 }}>
                    Post Content
                  </label>
                  <p style={{ 
                    whiteSpace: 'pre-wrap', 
                    color: 'var(--text-secondary)', 
                    fontSize: 13.5, 
                    lineHeight: 1.6,
                    maxHeight: '220px',
                    overflowY: 'auto',
                    background: 'var(--bg-input)',
                    padding: '12px 14px',
                    borderRadius: 8,
                    border: '1px solid var(--border)',
                    margin: 0
                  }}>
                    {viewingPost.body}
                  </p>
                </div>
              )}

              {/* Renders Image Media if present */}
              {viewingPost.image_url && (
                <div>
                  <label style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', display: 'block', marginBottom: 6 }}>
                    Image Attachment
                  </label>
                  <img 
                    src={viewingPost.image_url} 
                    alt="Post media" 
                    style={{ width: '100%', maxHeight: '350px', objectFit: 'contain', borderRadius: 8, border: '1px solid var(--border-bright)' }}
                  />
                </div>
              )}

              {/* Renders Video Media if present */}
              {viewingPost.video_url && (
                <div>
                  <label style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', display: 'block', marginBottom: 6 }}>
                    Video Attachment
                  </label>
                  <video 
                    src={viewingPost.video_url} 
                    controls 
                    style={{ width: '100%', maxHeight: '350px', borderRadius: 8, border: '1px solid var(--border-bright)' }}
                  />
                </div>
              )}

              {/* Renders generic File/Attachment Link if present */}
              {viewingPost.file_url && (
                <div>
                  <label style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', display: 'block', marginBottom: 6 }}>
                    File Attachment
                  </label>
                  <a 
                    href={viewingPost.file_url} 
                    target="_blank" 
                    rel="noreferrer" 
                    className="btn btn-ghost w-full"
                    style={{ justifyContent: 'center', gap: 8, color: 'var(--accent)', borderColor: 'var(--accent-glow)' }}
                  >
                    📎 Download Attachment File
                  </a>
                </div>
              )}
              
              <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                Posted on {new Date(viewingPost.created_at).toLocaleString()}
              </div>
            </div>

            <div className="modal-footer" style={{ marginTop: 28, paddingTop: 16, borderTop: '1px solid var(--border)' }}>
              <button 
                className="btn btn-danger" 
                onClick={() => {
                  const p = viewingPost;
                  setViewingPost(null);
                  deletePost(p);
                }}
              >
                <TrashIcon style={{ width: 12, height: 12 }} />
                Delete Post
              </button>
              <button className="btn btn-ghost" onClick={() => setViewingPost(null)}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}

import { createClient } from '@supabase/supabase-js'

// Same Supabase project as the Flutter app
const SUPABASE_URL = 'https://xenbdmepnvaqfuiwoxix.supabase.co'
const SUPABASE_ANON_KEY = 'sb_publishable_3J0IeIYrO33KqTbzNgGvtg_NE7u7A6r'

// Hardcoded admin email — only this account can access the dashboard
// Change this to your actual email address
export const ADMIN_EMAIL = 'saverites2026@gmail.com'

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// Create an unauthenticated client instance to perform actions as the 'anon' role (useful for bypassing authenticated-only RLS restrictions on delete)
export const anonSupabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false
  }
})

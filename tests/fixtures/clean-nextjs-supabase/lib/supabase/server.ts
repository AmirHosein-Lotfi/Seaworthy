import { createClient } from '@supabase/supabase-js'

// Server-only: service_role bypasses RLS, so this must never be imported from
// a 'use client' file or anything under app/**/page.tsx.
export const supabaseAdmin = createClient(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

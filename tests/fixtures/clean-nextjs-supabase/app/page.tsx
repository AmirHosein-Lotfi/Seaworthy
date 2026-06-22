'use client'

import { supabase } from '../lib/supabase/client'
import { useEffect, useState } from 'react'

export default function Home() {
  const [users, setUsers] = useState<any[]>([])

  useEffect(() => {
    supabase.from('users').select('*').then(({ data }) => setUsers(data ?? []))
  }, [])

  return <pre>{JSON.stringify(users)}</pre>
}

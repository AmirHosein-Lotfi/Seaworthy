import { NextRequest } from 'next/server'
import { getServerSession } from 'next-auth'
import { supabaseAdmin } from '../../../../lib/supabase/server'

export async function PUT(req: NextRequest) {
  const session = await getServerSession()
  if (!session?.user?.id) {
    return Response.json({ error: 'unauthorized' }, { status: 401 })
  }

  const body = await req.json()
  const { id, ...fields } = body

  const { data, error } = await supabaseAdmin
    .from('projects')
    .update(fields)
    .eq('id', id)
    .eq('user_id', session.user.id)

  return Response.json({ data, error })
}

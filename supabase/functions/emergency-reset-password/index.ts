import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.77.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get request body
    const { email, password } = await req.json()

    if (!email || !password) {
      return new Response(JSON.stringify({ error: 'Email and password required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log(`Emergency reset requested for: ${email}`)

    // First verify this email has admin_master role
    const { data: targetUser, error: getUserError } = await supabaseClient.auth.admin.listUsers()
    
    if (getUserError) {
      console.error('Error listing users:', getUserError)
      return new Response(JSON.stringify({ error: getUserError.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const userToUpdate = targetUser.users.find(u => u.email === email)
    
    if (!userToUpdate) {
      console.error('User not found:', email)
      return new Response(JSON.stringify({ error: 'User not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Verify user has admin_master role
    const { data: profile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('role')
      .eq('id', userToUpdate.id)
      .single()

    if (profileError) {
      console.error('Error fetching profile:', profileError)
      return new Response(JSON.stringify({ error: 'Profile not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    if (profile?.role !== 'admin_master') {
      console.error('User is not admin_master:', email)
      return new Response(JSON.stringify({ error: 'Only admin_master accounts can use emergency reset' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Update user password
    const { data, error } = await supabaseClient.auth.admin.updateUserById(
      userToUpdate.id,
      { password }
    )

    if (error) {
      console.error('Error updating password:', error)
      return new Response(JSON.stringify({ error: error.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log(`Password successfully updated for: ${email}`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Password updated for ${email}` 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { code, redirect_uri } = await req.json()
    if (!code || !redirect_uri) {
      return new Response(
        JSON.stringify({ error: 'missing_params', message: 'code and redirect_uri required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 1. Exchange code for Patreon access token
    const tokenRes = await fetch('https://www.patreon.com/api/oauth2/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        grant_type: 'authorization_code',
        client_id: Deno.env.get('PATREON_CLIENT_ID')!,
        client_secret: Deno.env.get('PATREON_CLIENT_SECRET')!,
        redirect_uri,
      }),
    })
    const tokenData = await tokenRes.json()
    if (!tokenData.access_token) {
      return new Response(
        JSON.stringify({ error: 'auth_failed', message: 'Failed to get Patreon token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 2. Get Patreon identity + memberships + tiers
    const identityRes = await fetch(
      'https://www.patreon.com/api/oauth2/v2/identity?include=memberships.currently_entitled_tiers&fields[user]=full_name,email&fields[member]=patron_status&fields[tier]=title',
      { headers: { Authorization: `Bearer ${tokenData.access_token}` } }
    )
    const identity = await identityRes.json()
    const patreonId = identity.data?.id
    const fullName = identity.data?.attributes?.full_name || 'Player'
    const email = identity.data?.attributes?.email

    if (!patreonId) {
      return new Response(
        JSON.stringify({ error: 'auth_failed', message: 'Could not get Patreon identity' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 3. Check for active membership
    const included = identity.included || []
    const memberships = included.filter((i: any) => i.type === 'member')
    const isActivePatron = memberships.some(
      (m: any) => m.attributes?.patron_status === 'active_patron'
    )

    if (!isActivePatron) {
      return new Response(
        JSON.stringify({ error: 'not_a_patron', message: 'You need an active Patreon membership to access premium features.' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 4. Extract tier title from included tier objects
    const tiers = included.filter((i: any) => i.type === 'tier')
    const tierTitle = tiers.length > 0 ? tiers[tiers.length - 1].attributes?.title || null : null

    // 5. Create or find Supabase user
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Look up existing user by patreon_id
    const { data: existingProfile } = await supabaseAdmin
      .from('profiles')
      .select('user_id')
      .eq('patreon_id', patreonId)
      .single()

    let userId: string

    if (existingProfile) {
      userId = existingProfile.user_id
      // Update display name and tier in case they changed
      await supabaseAdmin
        .from('profiles')
        .update({ display_name: fullName, patreon_tier: tierTitle })
        .eq('user_id', userId)
    } else {
      // Create new user
      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email: email || `patreon_${patreonId}@placeholder.local`,
        email_confirm: true,
        user_metadata: { full_name: fullName, patreon_id: patreonId },
      })
      if (createError || !newUser.user) {
        return new Response(
          JSON.stringify({ error: 'auth_failed', message: 'Failed to create user' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      userId = newUser.user.id

      // Create profile with patreon_id and tier (the trigger may have already created a row, so upsert)
      await supabaseAdmin
        .from('profiles')
        .upsert({ user_id: userId, display_name: fullName, patreon_id: patreonId, patreon_tier: tierTitle })
    }

    // 6. Generate session for the user
    const { data: linkData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'magiclink',
      email: email || `patreon_${patreonId}@placeholder.local`,
    })
    if (linkError || !linkData) {
      return new Response(
        JSON.stringify({ error: 'auth_failed', message: 'Failed to generate session' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Extract the token from the magic link and verify it to get a session
    const token_hash = linkData.properties?.hashed_token
    const { data: sessionData, error: verifyError } = await supabaseAdmin.auth.verifyOtp({
      type: 'magiclink',
      token_hash: token_hash!,
    })

    if (verifyError || !sessionData.session) {
      return new Response(
        JSON.stringify({ error: 'auth_failed', message: 'Failed to create session' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ session: sessionData.session, tier: tierTitle }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    return new Response(
      JSON.stringify({ error: 'auth_failed', message: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

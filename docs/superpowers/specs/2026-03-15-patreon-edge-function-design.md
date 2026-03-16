# Patreon OAuth via Supabase Edge Function

## Overview

Replace the non-functional `signInWithOAuth({ provider: 'patreon' })` call with a manual Patreon OAuth flow. A Supabase Edge Function handles the server-side token exchange, Patreon membership verification, and Supabase session creation. Only active Patreon members can obtain a session.

## Auth Flow

1. User clicks "Login with Patreon" in the app.
2. `auth.js` redirects the browser to Patreon's authorize URL:
   ```
   https://www.patreon.com/oauth2/authorize?response_type=code&client_id=CLIENT_ID&redirect_uri=REDIRECT_URI&scope=identity%20identity.memberships
   ```
3. User approves on Patreon.
4. Patreon redirects back to the app's redirect URI with a `code` query param (e.g., `https://yourapp.com/mobile/index.html?code=XXXX`).
5. `auth.js` detects the `code` param on page load, calls the Supabase Edge Function `patreon-auth` with `{ code, redirect_uri }`.
6. The Edge Function:
   - Exchanges the code for a Patreon access token via `POST https://www.patreon.com/api/oauth2/token`.
   - Calls `GET https://www.patreon.com/api/oauth2/v2/identity?include=memberships&fields[user]=full_name,email&fields[member]=patron_status` with the access token.
   - Checks if the user has at least one membership with `patron_status === 'active_patron'`.
   - If not an active patron: returns `{ error: 'not_a_patron' }`.
   - If active patron: looks up the user by `patreon_id` in the `profiles` table. If found, generates a session for the existing Supabase user. If not found, creates a new Supabase user via admin API, creates a profile row with `patreon_id` and `display_name`, and generates a session.
   - Returns `{ session }` containing the access token, refresh token, and user object.
7. `auth.js` receives the session, stores it via `supabase.auth.setSession()`, and reloads the page.

## Database Changes

Add `patreon_id` column to `profiles` table:

```sql
ALTER TABLE profiles ADD COLUMN patreon_id TEXT UNIQUE;
```

Update the auto-creation trigger to accept `patreon_id` (the Edge Function will handle profile creation directly, so the trigger only needs to handle non-Patreon signups — no change needed to the trigger).

## Edge Function: `patreon-auth`

**Path:** `supabase/functions/patreon-auth/index.ts`

**Method:** POST

**Request body:**
```json
{
  "code": "string — OAuth authorization code from Patreon redirect",
  "redirect_uri": "string — must match the redirect URI used in the authorize request"
}
```

**Response (success):**
```json
{
  "session": {
    "access_token": "...",
    "refresh_token": "...",
    "user": { "id": "...", "email": "..." }
  }
}
```

**Response (not a patron):**
```json
{
  "error": "not_a_patron",
  "message": "You need an active Patreon membership to access premium features."
}
```

**Response (other error):**
```json
{
  "error": "auth_failed",
  "message": "..."
}
```

### Edge Function Implementation

```typescript
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

    // 2. Get Patreon identity + memberships
    const identityRes = await fetch(
      'https://www.patreon.com/api/oauth2/v2/identity?include=memberships&fields[user]=full_name,email&fields[member]=patron_status',
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
    const memberships = identity.included?.filter((i: any) => i.type === 'member') || []
    const isActivePatron = memberships.some(
      (m: any) => m.attributes?.patron_status === 'active_patron'
    )

    if (!isActivePatron) {
      return new Response(
        JSON.stringify({ error: 'not_a_patron', message: 'You need an active Patreon membership to access premium features.' }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 4. Create or find Supabase user
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
      // Update display name in case it changed
      await supabaseAdmin
        .from('profiles')
        .update({ display_name: fullName })
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

      // Create profile with patreon_id (the trigger may have already created a row, so upsert)
      await supabaseAdmin
        .from('profiles')
        .upsert({ user_id: userId, display_name: fullName, patreon_id: patreonId })
    }

    // 5. Generate session for the user
    // Use admin.generateLink to create a magic link, then exchange it
    // Or use a custom JWT approach. The simplest: generate a magic link token.
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
      JSON.stringify({ session: sessionData.session }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err) {
    return new Response(
      JSON.stringify({ error: 'auth_failed', message: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
```

### CORS Shared Helper

**Path:** `supabase/functions/_shared/cors.ts`

```typescript
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
```

## Changes to Existing Files

### web/shared/supabase-config.js

Add Patreon client ID (public, safe for browser) and redirect URI:

```javascript
var SUPABASE_URL = 'https://yegbudbzbsnrwcjtygro.supabase.co';
var SUPABASE_ANON_KEY = 'sb_publishable_3Gm24GXAfwQIGdz4UG3FBQ_MpFB438U';
var PATREON_CLIENT_ID = 'YOUR_PATREON_CLIENT_ID';
var PATREON_REDIRECT_URI = window.location.origin + '/mobile/index.html';
```

### web/shared/auth.js

Replace `loginWithPatreon()` — instead of calling `supabase.auth.signInWithOAuth`, redirect directly to Patreon's authorize URL:

```javascript
async function loginWithPatreon() {
  var params = new URLSearchParams({
    response_type: 'code',
    client_id: PATREON_CLIENT_ID,
    redirect_uri: PATREON_REDIRECT_URI,
    scope: 'identity identity.memberships'
  });
  window.location.href = 'https://www.patreon.com/oauth2/authorize?' + params.toString();
}
```

Add code-handling logic to the `authReady` initialization. On page load, check for a `code` query param. If present, call the Edge Function to exchange it for a session:

```javascript
// Inside the authReady IIFE, before getSession():
var urlParams = new URLSearchParams(window.location.search);
var patreonCode = urlParams.get('code');
if (patreonCode && !_mockMode) {
  // Clean the URL immediately
  if (window.history.replaceState) {
    window.history.replaceState({}, '', window.location.pathname);
  }
  // Exchange code for session via Edge Function
  return fetch(SUPABASE_URL + '/functions/v1/patreon-auth', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ code: patreonCode, redirect_uri: PATREON_REDIRECT_URI })
  })
  .then(function(res) { return res.json(); })
  .then(function(data) {
    if (data.error) {
      console.warn('Patreon auth error:', data.message);
      _session = null;
      return;
    }
    // Set the session in Supabase client
    return getSupabase().auth.setSession({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token
    }).then(function(result) {
      _session = result.data.session;
      // Fetch display name
      if (_session && _session.user) {
        return getSupabase().from('profiles')
          .select('display_name')
          .eq('user_id', _session.user.id)
          .single()
          .then(function(res) {
            if (res.data) _displayName = res.data.display_name;
          }).catch(function() {});
      }
    });
  })
  .catch(function(err) {
    console.warn('Patreon auth failed:', err);
    _session = null;
  });
}
```

If no `code` param, fall through to the existing `getSession()` flow (unchanged).

### web/shared/supabase-schema.sql

Add the `patreon_id` column:

```sql
ALTER TABLE profiles ADD COLUMN patreon_id TEXT UNIQUE;
```

## Secrets Configuration

Set via Supabase CLI before deploying:

```bash
supabase secrets set PATREON_CLIENT_ID=your_client_id
supabase secrets set PATREON_CLIENT_SECRET=your_client_secret
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically available in Edge Functions.

## Error Handling (Client Side)

When the Edge Function returns an error, `auth.js` should show a user-friendly message. Add a `_authError` variable that pages can check:

```javascript
var _authError = null;
// ... in the code exchange flow:
if (data.error === 'not_a_patron') {
  _authError = data.message;
}
```

Pages can check `_authError` after `authReady` resolves and display a toast/alert.

## Prerequisites

1. Register a Patreon OAuth app at patreon.com/portal/registration/register-clients.
2. Set redirect URI to your production URL (e.g., `https://yourapp.com/mobile/index.html`). For local testing, also add `http://localhost:3124/mobile/index.html`.
3. Copy the Client ID into `supabase-config.js`.
4. Install the Supabase CLI: `npm install -g supabase`.
5. Link your project: `supabase link --project-ref yegbudbzbsnrwcjtygro`.
6. Set secrets: `supabase secrets set PATREON_CLIENT_ID=... PATREON_CLIENT_SECRET=...`.
7. Deploy: `supabase functions deploy patreon-auth`.
8. Run the ALTER TABLE in the Supabase SQL editor.

## Out of Scope

- Patreon token refresh (session is created via Supabase Auth, which handles its own refresh)
- Membership tier checking (any active patron qualifies)
- Patreon webhook for membership changes (user must re-login if membership lapses)

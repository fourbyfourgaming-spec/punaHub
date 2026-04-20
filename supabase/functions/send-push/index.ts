// ═══════════════════════════════════════════════════════════
//  SUPABASE EDGE FUNCTION: send-push
//  Sends Web Push notifications to subscribed users
// ═══════════════════════════════════════════════════════════

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Web Push library
import webpush from 'https://esm.sh/web-push@3.6.6'

// ═══════════════════════════════════════════════════════════
//  CONFIGURATION
// ═══════════════════════════════════════════════════════════

// VAPID Keys - Generate at https://vapidkeys.com
// Set these in Supabase Dashboard → Project Settings → Edge Functions Secrets
const VAPID_PUBLIC_KEY = Deno.env.get('VAPID_PUBLIC_KEY') || ''
const VAPID_PRIVATE_KEY = Deno.env.get('VAPID_PRIVATE_KEY') || ''
const VAPID_SUBJECT = Deno.env.get('VAPID_SUBJECT') || 'mailto:admin@punahub.com'

// Initialize web-push
webpush.setVapidDetails(
  VAPID_SUBJECT,
  VAPID_PUBLIC_KEY,
  VAPID_PRIVATE_KEY
)

// ═══════════════════════════════════════════════════════════
//  CORS HEADERS
// ═══════════════════════════════════════════════════════════

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ═══════════════════════════════════════════════════════════
//  MAIN HANDLER
// ═══════════════════════════════════════════════════════════

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // ═══════════════════════════════════════════════════════
    //  AUTHENTICATION
    // ═══════════════════════════════════════════════════════
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const {
      data: { user },
    } = await supabaseClient.auth.getUser()

    // ═══════════════════════════════════════════════════════
    //  PARSE REQUEST
    // ═══════════════════════════════════════════════════════

    const { to_email, title, body, data = {}, icon, badge } = await req.json()

    if (!to_email || !title || !body) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: to_email, title, body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ═══════════════════════════════════════════════════════
    //  FETCH SUBSCRIPTIONS
    // ═══════════════════════════════════════════════════════

    const { data: subscriptions, error: subError } = await supabaseClient
      .from('punahub_push_subs')
      .select('*')
      .eq('user_email', to_email)

    if (subError) {
      console.error('Error fetching subscriptions:', subError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch subscriptions' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!subscriptions || subscriptions.length === 0) {
      return new Response(
        JSON.stringify({ message: 'No push subscriptions found for user', sent: 0 }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // ═══════════════════════════════════════════════════════
    //  SEND PUSH NOTIFICATIONS
    // ═══════════════════════════════════════════════════════

    const notificationPayload = JSON.stringify({
      title,
      body,
      icon: icon || '/icon-192x192.png',
      badge: badge || '/badge-72x72.png',
      tag: `punahub-${data?.type || 'notif'}`,
      requireInteraction: false,
      data: {
        ...data,
        timestamp: Date.now(),
      },
      actions: [
        { action: 'open', title: 'Open' },
        { action: 'dismiss', title: 'Dismiss' }
      ]
    })

    const results = []
    const failedEndpoints = []

    for (const sub of subscriptions) {
      try {
        const pushSubscription = {
          endpoint: sub.endpoint,
          keys: {
            p256dh: sub.p256dh,
            auth: sub.auth
          }
        }

        await webpush.sendNotification(pushSubscription, notificationPayload)
        
        results.push({
          endpoint: sub.endpoint.substring(0, 50) + '...',
          status: 'sent'
        })
        
        console.log(`Push sent to ${to_email}: ${title}`)
      } catch (err: any) {
        console.error(`Push failed for ${to_email}:`, err.message)
        
        results.push({
          endpoint: sub.endpoint.substring(0, 50) + '...',
          status: 'failed',
          error: err.message
        })

        // If subscription is expired/invalid, mark for deletion
        if (err.statusCode === 404 || err.statusCode === 410) {
          failedEndpoints.push(sub.id)
        }
      }
    }

    // ═══════════════════════════════════════════════════════
    //  CLEAN UP EXPIRED SUBSCRIPTIONS
    // ═══════════════════════════════════════════════════════

    if (failedEndpoints.length > 0) {
      const { error: deleteError } = await supabaseClient
        .from('punahub_push_subs')
        .delete()
        .in('id', failedEndpoints)

      if (deleteError) {
        console.error('Error deleting expired subscriptions:', deleteError)
      } else {
        console.log(`Deleted ${failedEndpoints.length} expired subscriptions`)
      }
    }

    // ═══════════════════════════════════════════════════════
    //  RESPONSE
    // ═══════════════════════════════════════════════════════

    const successCount = results.filter(r => r.status === 'sent').length

    return new Response(
      JSON.stringify({
        success: true,
        sent: successCount,
        total: subscriptions.length,
        failed: failedEndpoints.length,
        results
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (err: any) {
    console.error('Unexpected error:', err)
    return new Response(
      JSON.stringify({ error: err.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

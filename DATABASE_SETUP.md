# punaHub Database & Push Notifications Setup

This guide walks you through setting up the **Supabase database** and **Push Notification system** for punaHub.

---

## ✅ What's Already Done

1. ✅ **Service Worker** created at `service-worker.js` - handles push events
2. ✅ **Push Notification API** added to `index.html` - subscribes users and sends notifications
3. ✅ **Database Schema** created at `supabase-setup.sql` - all tables and triggers
4. ✅ **Edge Function** created at `supabase/functions/send-push/index.ts` - server-side push sender
5. ✅ **Web App Manifest** created at `manifest.json` - PWA support

---

## 🚀 Step-by-Step Setup

### Step 1: Generate VAPID Keys

VAPID keys authenticate your push notifications with browsers.

```bash
# Option 1: Online generator (easiest)
# Go to: https://vapidkeys.com
# Copy the Public Key and Private Key

# Option 2: Using web-push CLI
npx web-push generate-vapid-keys
```

### Step 2: Update index.html

Edit `index.html` and replace the placeholder VAPID key:

```javascript
// Line ~10401 in index.html
const VAPID_PUBLIC_KEY = 'YOUR_PUBLIC_KEY_HERE';
```

### Step 3: Create Supabase Project

1. Go to [supabase.com](https://supabase.com) → Sign up free
2. Create **New Project**
3. Wait 1-2 minutes for project to initialize
4. Go to **Project Settings → API**
5. Copy:
   - **Project URL** → paste in `index.html` as `SB_URL`
   - **anon/public key** → paste in `index.html` as `SB_ANON`

### Step 4: Run Database Setup

1. In Supabase Dashboard → **SQL Editor**
2. Click **New Query**
3. Copy the contents of `supabase-setup.sql`
4. Click **Run**

This creates all tables:
- `punahub_users` - User profiles
- `punahub_reels` - Posts/videos
- `punahub_follows` - Follow relationships
- `punahub_push_subs` - Push notification subscriptions
- `punahub_notifs` - Notification history
- `punahub_likes` - Like data
- `punahub_comments` - Comments
- Storage bucket `punahub` - For avatars/media

### Step 5: Deploy Edge Function

The Edge Function sends push notifications from the server:

```bash
# Install Supabase CLI (if not already installed)
npm install -g supabase

# Login to Supabase
supabase login

# Link your project (get project ref from Dashboard URL)
supabase link --project-ref YOUR_PROJECT_REF

# Deploy the function
supabase functions deploy send-push
```

### Step 6: Set Environment Variables

In Supabase Dashboard → **Project Settings → Edge Functions Secrets**:

```
VAPID_PUBLIC_KEY=your_public_key_from_step_1
VAPID_PRIVATE_KEY=your_private_key_from_step_1
VAPID_SUBJECT=mailto:your-email@example.com
```

### Step 7: Enable Realtime

1. Go to **Database → Replication**
2. Enable realtime for:
   - `punahub_notifs`
   - `punahub_follows`
   - `punahub_reels`
   - `punahub_likes`
   - `punahub_comments`

---

## 🔧 How It Works

### Database Flow
```
User Action (follow/like/comment)
    ↓
Supabase Table Updated
    ↓
Database Trigger Fires
    ↓
Notification Record Created
    ↓
Realtime Broadcasts to All Devices
    ↓
Push Sent to Offline Devices (via Edge Function)
```

### Push Notification Flow
```
1. User enables notifications in browser
2. Browser generates push subscription
3. Subscription saved to punahub_push_subs table
4. When someone follows/likes/comments:
   - Edge Function queries subscriptions
   - Sends web push via VAPID
   - User receives notification even if app closed
```

---

## 📝 API Reference

### Client-Side Push API (`window.__punaPush`)

```javascript
// Request notification permission
await window.__punaPush.requestPermission(userEmail);

// Check permission status
const perm = window.__punaPush.getPermission(); // 'granted' | 'denied' | 'default'

// Send push to another user
await window.__punaPush.send(toEmail, 'Title', 'Body', {
  type: 'follow',
  fromEmail: currentUser.email
});

// Show local notification (when app is open)
window.__punaPush.showLocal('New Follower', {
  body: 'Someone followed you!',
  icon: '/icon-192x192.png'
});

// Create toggle button in UI
window.__punaPush.createToggle('settings-container');
```

### Edge Function Endpoint

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/send-push \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to_email": "user@example.com",
    "title": "New Follower",
    "body": "Someone started following you!",
    "data": { "type": "follow", "fromEmail": "other@example.com" }
  }'
```

---

## 🎨 Adding UI Controls

Add this to your settings page to let users toggle notifications:

```javascript
// In your settings/profile page code
function initPushSettings() {
  const container = document.getElementById('push-settings');
  if (!container) return;
  
  // Create the toggle button
  window.__punaPush.createToggle('push-settings');
  
  // Or manually check status
  const status = document.createElement('div');
  status.id = 'push-status';
  status.innerHTML = 'Push status: ' + window.__punaPush.getPermission();
  container.appendChild(status);
}

// Call after user logs in
initPushSettings();
```

---

## 🐛 Troubleshooting

### Push notifications not appearing
1. Check browser console for errors
2. Verify VAPID keys are set correctly
3. Ensure `service-worker.js` is accessible at root
4. Check Supabase Edge Function logs

### Database not syncing
1. Verify SB_URL and SB_ANON in index.html
2. Check browser console for Supabase errors
3. Ensure database tables were created (check SQL Editor)

### Notifications not sent to other users
1. Verify `punahub_push_subs` has subscription records
2. Check Edge Function logs in Supabase Dashboard
3. Ensure VAPID_PRIVATE_KEY is set in Edge Function secrets

---

## 📱 Supported Browsers

- ✅ Chrome (desktop & Android)
- ✅ Firefox (desktop)
- ✅ Safari (macOS Ventura+, iOS 16.4+)
- ✅ Edge (desktop & Android)
- ⚠️ Safari iOS < 16.4: Limited support

---

## 🔐 Security Notes

- VAPID **public key** is safe to expose in frontend code
- VAPID **private key** must ONLY be in Edge Function secrets
- Supabase `anon` key is safe for client-side (RLS protects data)
- Enable RLS policies in production (see commented section in SQL file)

---

## 🎉 You're Done!

Your punaHub now has:
- ✅ Persistent cloud database
- ✅ Real-time sync across devices
- ✅ Push notifications (even when app is closed)
- ✅ Auto-generated notifications on follow/like/comment

# FCM Push Notifications — Architecture & Workflow

## Overview

When the admin updates an order's status, the customer receives a push notification in real-time — even if the app is closed. This is powered by Firebase Cloud Messaging (FCM).

## Architecture

```
Admin updates order status
        │
        ▼
Firestore orders/{orderId} document updated
        │
        ▼
Cloud Function (sendOrderNotification) triggers on onDocumentWritten
        │
        ├── Reads new status + orderNumber from the updated order
        ├── Fetches user's FCM tokens from users/{userId}.fcmTokens[]
        └── Sends push notification via Firebase Admin SDK to all device tokens
                 │
                 ▼
        Customer's device receives notification:
          ├── App foreground → flutter_local_notifications shows it
          ├── App background → System notification tray
          └── App terminated  → System notification tray (FCM auto-handles)
```

## Files Changed

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Added `firebase_messaging: ^15.2.0` and `flutter_local_notifications: ^18.0.0` |
| `lib/services/notification_service.dart` | Full FCM rewrite: token registration, permission requests, foreground/background/terminated handling, local notification display |
| `lib/services/firebase_service.dart` | Added `saveFcmToken()`, `getFcmTokens()`, `removeFcmToken()` for storing tokens in user docs |
| `lib/screens/splash/splash_screen.dart` | Wires FCM init, calls `setUserId()` and `setupMessageHandlers()` |
| `functions/index.js` | Cloud Function — triggers on order updates, sends FCM via Admin SDK |
| `functions/package.json` | Node.js dependencies for Cloud Function |
| `firebase.json` | Added functions config |
| `.github/workflows/build-apk.yml` | Added functions install + deploy steps |
| `lib/services/firebase_service.dart` | `updateOrderStatus()` now sets `deliveredAt` when status = 'delivered' |

## Notification Messages

| Status Change | Title | Body |
|---------------|-------|------|
| `pending → confirmed` | تم تأكيد الطلب ✓ | تم تأكيد الطلب رقم ANF-XXXXX وسيتم تجهيزه قريباً |
| `confirmed → processing` | طلبك قيد التجهيز | طلبك رقم ANF-XXXXX قيد التجهيز الآن |
| `processing → shipped` | تم شحن طلبك 🚚 | طلبك رقم ANF-XXXXX في طريقه إليك |
| `shipped → delivered` | تم توصيل طلبك ✅ | تم توصيل الطلب رقم ANF-XXXXX بنجاح |
| `any → cancelled` | تم إلغاء الطلب | تم إلغاء الطلب رقم ANF-XXXXX |

## FCM Token Storage

Tokens are stored in Firestore `users/{userId}` documents as an array field `fcmTokens`:
```json
{
  "fcmTokens": ["dQw4w9WgXcQ:...", "abc123..."]
}
```

- Up to **5 tokens** per user (handles multiple devices)
- Stale tokens are **not auto-removed** (could be cleaned by client on error)
- Token is registered when user logs in (`NotificationService.setUserId()`)
- Token refresh is tracked via `onTokenRefresh` stream

## Cloud Function Details

- **Trigger**: `onDocumentWritten` for `orders/{orderId}`
- **Region**: `us-central1`
- **Runtime**: Node.js 22
- **Logic**: Ignores document creation (only sends on status **changes**)
- **Error handling**: Logs stale tokens but doesn't delete them (client-side removal planned)
- **Data payload**: Includes `{ type: 'order_update', orderId, status, orderNumber }` for deep-linking

## Deployment

The Cloud Function is deployed automatically via GitHub Actions on every push to master:
```yaml
- name: Install Functions deps
  working-directory: ./functions
  run: npm ci --only=production

- name: Deploy Cloud Functions
  uses: w9jds/firebase-action@v15.23.0
  with:
    args: deploy --only functions:sendOrderNotification --project alafif-newform
  env:
    FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

### ⚠️ Blaze Plan Required

**Firebase Cloud Functions require the Blaze (pay-as-you-go) plan.** The Spark (free) plan does not support Cloud Functions. If the user is on Spark:
1. The CI deploy step will fail with a billing-related error
2. Upgrade at: https://console.firebase.google.com/project/alafif-newform/usage/details
3. **Free tier**: 2M invocations/month — should cover this app's usage for free
4. No credit card charges unless you exceed the free tier quotas

### Manual deployment (if CI fails)
```bash
cd ~/projects/alafif-newform/functions
npm ci
cd ..
npx firebase deploy --only functions:sendOrderNotification --project alafif-newform
```

## Android Permissions

For Android 13+ (API 33+), the app requests `POST_NOTIFICATIONS` permission at runtime via `FirebaseMessaging.requestPermission()`. This is handled by the notification service in `splash_screen.dart`.

No changes needed to `AndroidManifest.xml` — FCM's manifest merger adds the necessary receivers/services automatically.

## How to Test

1. Install the APK on a test device
2. Login as a customer → FCM token is registered in Firestore
3. Login as admin on another device (or same device with different account)
4. Create an order, then go to إدارة الطلبات and update the status
5. The customer device should receive a push notification immediately

## Future Improvements

- **Deep linking**: Navigate to order tracking screen when tapping notification
- **Admin notifications**: Notify admin when a new order is placed
- **FCM token cleanup**: Remove stale tokens from Firestore when they fail
- **Group notifications**: Use FCM topic-based messaging for bulk alerts

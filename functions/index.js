/**
 * Firebase Cloud Functions for Alafif Newform
 *
 * 1. sendOrderNotification — sends FCM to customer when admin updates order status
 * 2. sendAdminNewOrderNotification — sends FCM to all admins when a new order is placed
 *
 * Triggers: Firestore `orders/{orderId}` onWrite / onDocumentCreated
 * Reads FCM tokens from `users/{userId}.fcmTokens[]`
 */

const { onDocumentWritten, onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

// ────────────────────────────────────────────
//  Helper: send a message to a list of tokens
// ────────────────────────────────────────────

async function _sendToTokens(fcmTokens, title, body, data) {
  if (!fcmTokens || fcmTokens.length === 0) return { sent: 0, failed: 0 };

  const results = await Promise.allSettled(
    fcmTokens.map(async (token) => {
      const message = {
        token,
        notification: { title, body },
        data,
        android: {
          priority: 'high',
          notification: {
            channelId: 'order_updates',
            icon: 'ic_launcher',
            color: '#1B5E20',
            sound: 'default',
          },
        },
      };

      try {
        await getMessaging().send(message);
        console.log(`  ✅ Sent to token: ${token.substring(0, 10)}...`);
        return { token, success: true };
      } catch (error) {
        if (error.code === 'messaging/registration-token-not-registered' ||
            error.code === 'messaging/invalid-registration-token') {
          console.log(`  🗑️ Stale token: ${token.substring(0, 10)}...`);
        }
        console.error(`  ❌ Failed: ${error.message}`);
        return { token, success: false };
      }
    })
  );

  const sent = results.filter((r) => r.status === 'fulfilled' && r.value.success).length;
  const failed = results.filter((r) => r.status === 'fulfilled' && !r.value.success).length;
  return { sent, failed };
}

// ════════════════════════════════════════════
//  1. إشعار للعميل — عند تحديث حالة الطلب
// ════════════════════════════════════════════

exports.sendOrderNotification = onDocumentWritten(
  {
    document: 'orders/{orderId}',
    region: 'us-central1',
  },
  async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();

    // تجاهل إنشاء الطلب (نريد التحديثات فقط)
    if (!beforeData || !afterData) return;

    const beforeStatus = beforeData.status || '';
    const afterStatus = afterData.status || '';

    // إذا لم تتغير الحالة، تجاهل
    if (beforeStatus === afterStatus) return;

    console.log(`📦 Order ${event.params.orderId}: ${beforeStatus} → ${afterStatus}`);

    // ترجمة الحالة إلى عنوان عربي
    const titles = {
      confirmed: 'تم تأكيد الطلب ✓',
      processing: 'طلبك قيد التجهيز',
      shipped: 'تم شحن طلبك 🚚',
      delivered: 'تم توصيل طلبك ✅',
      cancelled: 'تم إلغاء الطلب',
    };

    const bodies = {
      confirmed: (num) => `تم تأكيد الطلب رقم ${num} وسيتم تجهيزه قريباً`,
      processing: (num) => `طلبك رقم ${num} قيد التجهيز الآن`,
      shipped: (num) => `طلبك رقم ${num} في طريقه إليك 🚚`,
      delivered: (num) => `تم توصيل الطلب رقم ${num} بنجاح ✅`,
      cancelled: (num) => `تم إلغاء الطلب رقم ${num}`,
    };

    const title = titles[afterStatus] || 'تحديث الطلب';
    const body = bodies[afterStatus]
      ? bodies[afterStatus](afterData.orderNumber || '')
      : `تم تحديث حالة الطلب رقم ${afterData.orderNumber || ''}`;

    // الحصول على userId من الطلب
    const userId = afterData.userId || afterData.user_id;
    if (!userId) {
      console.log('⚠️ No userId in order data');
      return;
    }

    // جلب FCM tokens من وثيقة المستخدم
    let fcmTokens = [];
    try {
      const userDoc = await getFirestore().collection('users').doc(userId).get();
      if (userDoc.exists) {
        fcmTokens = userDoc.data()?.fcmTokens || [];
      }
    } catch (err) {
      console.error('⚠️ Failed to fetch user FCM tokens:', err);
    }

    if (fcmTokens.length === 0) {
      console.log('⚠️ No FCM tokens found for user', userId);
      return;
    }

    console.log(`📱 Sending to ${fcmTokens.length} device(s) for user ${userId}`);

    const { sent, failed } = await _sendToTokens(fcmTokens, title, body, {
      type: 'order_update',
      orderId: event.params.orderId,
      status: afterStatus,
      orderNumber: afterData.orderNumber || '',
    });

    console.log(`📊 Results: ${sent} sent, ${failed} failed`);
  }
);

// ════════════════════════════════════════════
//  2. إشعار للمدير — عند إنشاء طلب جديد
// ════════════════════════════════════════════

exports.sendAdminNewOrderNotification = onDocumentCreated(
  {
    document: 'orders/{orderId}',
    region: 'us-central1',
  },
  async (event) => {
    const orderData = event.data.data();
    if (!orderData) return;

    const orderNumber = orderData.orderNumber || '—';
    const customerName = orderData.shippingAddress?.fullName || 'عميل';
    const total = orderData.total || 0;
    const paymentMethod = orderData.paymentMethod || '—';

    console.log(`🆕 New order: ${orderNumber} — ${customerName} — ${total} ريال`);

    const title = '🆕 طلب جديد';
    const body = `طلب جديد رقم ${orderNumber} من ${customerName} بقيمة ${total} ريال`;

    // جلب جميع المستخدمين المديرين
    let adminTokens = [];
    try {
      const adminsSnapshot = await getFirestore()
        .collection('users')
        .where('isAdmin', '==', true)
        .get();

      for (const doc of adminsSnapshot.docs) {
        const tokens = doc.data().fcmTokens || [];
        adminTokens.push(...tokens);
      }

      // إزالة التكرارات
      adminTokens = [...new Set(adminTokens)];
    } catch (err) {
      console.error('⚠️ Failed to fetch admin tokens:', err);
    }

    if (adminTokens.length === 0) {
      console.log('⚠️ No admin FCM tokens found');
      return;
    }

    console.log(`📱 Sending to ${adminTokens.length} admin device(s)`);

    const { sent, failed } = await _sendToTokens(adminTokens, title, body, {
      type: 'admin_new_order',
      orderId: event.params.orderId,
      orderNumber,
      customerName,
      total: String(total),
      paymentMethod,
    });

    console.log(`📊 Admin notifications: ${sent} sent, ${failed} failed`);
  }
);

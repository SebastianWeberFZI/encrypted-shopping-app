package de.sweber.encrypted_shopping_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Einkaufsliste auf dem Sperrbildschirm: eine angeheftete, stille Benachrichtigung
 * mit den offenen Artikeln der aktuellen Liste. Antippen hakt ab – ohne zu
 * entsperren (gleicher Weg wie im Widget). Aktualisiert sich nur, wenn sich die
 * Daten ändern; kein eigener Timer.
 */
object LockList {
    // Wichtigkeit „Standard“ (aber ohne Ton/Vibration): „lautlose“ Benachrichtigungen
    // blendet Android auf dem Sperrbildschirm standardmäßig aus.
    private const val CHANNEL = "liste_sperrbildschirm"
    private const val NOTIFICATION_ID = 4711
    const val KEY_ENABLED = "lock_list"

    private val smallSlots = intArrayOf(R.id.ns_slot_0, R.id.ns_slot_1, R.id.ns_slot_2)
    private val smallIcons = intArrayOf(R.id.ns_icon_0, R.id.ns_icon_1, R.id.ns_icon_2)
    private val smallTexts = intArrayOf(R.id.ns_text_0, R.id.ns_text_1, R.id.ns_text_2)
    private val slots = intArrayOf(R.id.nl_slot_0, R.id.nl_slot_1, R.id.nl_slot_2, R.id.nl_slot_3, R.id.nl_slot_4, R.id.nl_slot_5, R.id.nl_slot_6, R.id.nl_slot_7, R.id.nl_slot_8, R.id.nl_slot_9, R.id.nl_slot_10, R.id.nl_slot_11)
    private val icons = intArrayOf(R.id.nl_icon_0, R.id.nl_icon_1, R.id.nl_icon_2, R.id.nl_icon_3, R.id.nl_icon_4, R.id.nl_icon_5, R.id.nl_icon_6, R.id.nl_icon_7, R.id.nl_icon_8, R.id.nl_icon_9, R.id.nl_icon_10, R.id.nl_icon_11)
    private val specs = intArrayOf(R.id.nl_spec_0, R.id.nl_spec_1, R.id.nl_spec_2, R.id.nl_spec_3, R.id.nl_spec_4, R.id.nl_spec_5, R.id.nl_spec_6, R.id.nl_spec_7, R.id.nl_spec_8, R.id.nl_spec_9, R.id.nl_spec_10, R.id.nl_spec_11)
    private val texts = intArrayOf(R.id.nl_text_0, R.id.nl_text_1, R.id.nl_text_2, R.id.nl_text_3, R.id.nl_text_4, R.id.nl_text_5, R.id.nl_text_6, R.id.nl_text_7, R.id.nl_text_8, R.id.nl_text_9, R.id.nl_text_10, R.id.nl_text_11)

    fun refresh(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        val enabled = HomeWidgetPlugin.getData(context).getBoolean(KEY_ENABLED, false)
        val snap = ShopData.load(context)
        val list = snap.lists.firstOrNull { it.id == snap.defaultList } ?: snap.lists.firstOrNull()
        val items = list?.let { snap.items[it.id] } ?: emptyList()
        if (!enabled || list == null || items.isEmpty()) {
            nm.cancel(NOTIFICATION_ID)
            return
        }
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Liste auf dem Sperrbildschirm", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Offene Artikel zum Abhaken, auch ohne Entsperren"
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                    setShowBadge(false)
                    setSound(null, null)
                    enableVibration(false)
                })
        }
        val pkg = context.packageName
        fun RemoteViews.chip(slot: Int, icon: Int, text: Int, e: ShopEntry?, index: Int, spec: Int = 0) {
            if (e == null) {
                setViewVisibility(slot, View.INVISIBLE)
                return
            }
            setViewVisibility(slot, View.VISIBLE)
            setTextViewText(text, e.name)
            if (spec != 0) {
                setTextViewText(spec, e.spec)
                setViewVisibility(spec, if (e.spec.isEmpty()) View.GONE else View.VISIBLE)
            }
            val bmp = Piktos.bitmap(context, e.icon, 20)
            if (bmp != null) {
                setImageViewBitmap(icon, bmp)
                setViewVisibility(icon, View.VISIBLE)
            } else {
                setViewVisibility(icon, View.GONE)
            }
            setContentDescription(slot, "${e.name} abhaken")
            setOnClickPendingIntent(slot, PendingIntent.getBroadcast(context, 9000 + index,
                Intent(context, ShoppingCheckReceiver::class.java)
                    .setAction(ShopData.CHECK_ACTION)
                    .setData(Uri.parse("einkauf://check?item=${Uri.encode(e.id)}")),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        }
        val title = "${list.emoji} ${list.name} · ${items.size} offen"
        val small = RemoteViews(pkg, R.layout.notif_list_small).apply {
            for (i in smallSlots.indices) chip(smallSlots[i], smallIcons[i], smallTexts[i], items.getOrNull(i), i)
            val rest = items.size - smallSlots.size
            setTextViewText(R.id.ns_more, if (rest > 0) "+$rest" else "")
            setViewVisibility(R.id.ns_more, if (rest > 0) View.VISIBLE else View.GONE)
        }
        val big = RemoteViews(pkg, R.layout.notif_list_big).apply {
            setTextViewText(R.id.nl_title, "$title – antippen hakt ab")
            for (i in slots.indices) chip(slots[i], icons[i], texts[i], items.getOrNull(i), i, specs[i])
            // Leere Zeilen ausblenden
            val rows = intArrayOf(R.id.nl_row_0, R.id.nl_row_1, R.id.nl_row_2, R.id.nl_row_3)
            for (r in rows.indices) setViewVisibility(rows[r], if (items.size > r * 3) View.VISIBLE else View.GONE)
            val rest = items.size - slots.size
            setTextViewText(R.id.nl_more, if (rest > 0) "+ $rest weitere in der App" else "")
            setViewVisibility(R.id.nl_more, if (rest > 0) View.VISIBLE else View.GONE)
        }
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        builder
            .setSmallIcon(R.drawable.ic_stat_notify)
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setCustomContentView(small)
            .setCustomBigContentView(big)
            .setContentTitle(title)
            .setContentText(items.joinToString(", ") { it.name })
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setColor(list.color)
            .setSubText(list.name)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(ShopData.launchIntent(context, "einkauf://list?list=${list.id}", 9100))
        try {
            nm.notify(NOTIFICATION_ID, builder.build())
        } catch (_: SecurityException) {
            // Benachrichtigungen nicht erlaubt – dann eben nicht.
        }
    }
}

/** Nach Neustart oder App-Update die Sperrbildschirm-Liste wiederherstellen. */
class LockListBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            LockList.refresh(context)
        }
    }
}

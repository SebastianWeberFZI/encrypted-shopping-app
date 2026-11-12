package de.sweber.encrypted_shopping_app

import android.app.Activity
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import android.widget.ScrollView
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetBackgroundReceiver
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

/*
 * Einkaufslisten-Widget: offene Artikel einer Liste als Kacheln, Antippen hakt ab.
 * Die App liefert die Daten (JSON „shopping_data“) nur bei Änderungen – das Widget
 * selbst fragt nie periodisch ab (Energie).
 */

data class ShopList(val id: String, val name: String, val emoji: String, val color: Int)
data class ShopEntry(val id: String, val name: String, val emoji: String, val spec: String)
class ShopSnapshot(val lists: List<ShopList>, val items: Map<String, List<ShopEntry>>, val defaultList: String)

object ShopData {
    const val KEY = "shopping_data"
    const val CHECK_ACTION = "de.sweber.encrypted_shopping_app.CHECK_ITEM"
    private const val PREFS = "shopping_widget_config"
    private const val LAUNCH_ACTION = "es.antonborri.home_widget.action.LAUNCH"
    private const val BACKGROUND_ACTION = "es.antonborri.home_widget.action.BACKGROUND"
    private const val DEFAULT_COLOR = 0xFF2F7D6B

    /** Tolerant lesen: fehlende/unbekannte Felder dürfen das Widget nie zum Absturz bringen. */
    fun load(context: Context): ShopSnapshot {
        val raw = HomeWidgetPlugin.getData(context).getString(KEY, null) ?: return ShopSnapshot(emptyList(), emptyMap(), "")
        return try {
            val json = JSONObject(raw)
            val lists = ArrayList<ShopList>()
            json.optJSONArray("lists")?.let { arr ->
                for (i in 0 until arr.length()) {
                    val o = arr.optJSONObject(i) ?: continue
                    val id = o.optString("id")
                    if (id.isNotEmpty()) lists.add(ShopList(id, o.optString("n", "Liste"), o.optString("e", "🛒"),
                        o.optLong("c", DEFAULT_COLOR).toInt()))
                }
            }
            val items = HashMap<String, List<ShopEntry>>()
            json.optJSONObject("items")?.let { obj ->
                for (listId in obj.keys()) {
                    val arr = obj.optJSONArray(listId) ?: continue
                    items[listId] = (0 until arr.length()).mapNotNull { i ->
                        val o = arr.optJSONObject(i) ?: return@mapNotNull null
                        val id = o.optString("id")
                        if (id.isEmpty()) null else ShopEntry(id, o.optString("n"), o.optString("e", "🛍️"), o.optString("s"))
                    }
                }
            }
            ShopSnapshot(lists, items, json.optString("default_list"))
        } catch (e: Exception) {
            ShopSnapshot(emptyList(), emptyMap(), "")
        }
    }

    /** Gewählte Liste dieses Widgets – oder die aktuelle Liste der App. */
    fun listFor(context: Context, snap: ShopSnapshot, widgetId: Int): ShopList? {
        val chosen = chosenList(context, widgetId)
        val id = if (chosen.isNotEmpty() && snap.lists.any { it.id == chosen }) chosen else snap.defaultList
        return snap.lists.firstOrNull { it.id == id } ?: snap.lists.firstOrNull()
    }

    fun chosenList(context: Context, widgetId: Int): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("list_$widgetId", "") ?: ""

    fun choose(context: Context, widgetId: Int, listId: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("list_$widgetId", listId).apply()
    }

    fun forget(context: Context, ids: IntArray) {
        val e = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        for (id in ids) e.remove("list_$id")
        e.apply()
    }

    /** Sofortige Rückmeldung beim Abhaken: Artikel lokal aus den Widget-Daten nehmen. */
    fun removeLocally(context: Context, itemId: String) {
        val prefs = HomeWidgetPlugin.getData(context)
        val raw = prefs.getString(KEY, null) ?: return
        try {
            val json = JSONObject(raw)
            val items = json.optJSONObject("items") ?: return
            for (listId in items.keys()) {
                val arr = items.optJSONArray(listId) ?: continue
                val kept = JSONArray()
                for (i in 0 until arr.length()) {
                    val o = arr.optJSONObject(i)
                    if (o == null || o.optString("id") != itemId) kept.put(arr.opt(i))
                }
                items.put(listId, kept)
            }
            prefs.edit().putString(KEY, json.toString()).apply()
        } catch (_: Exception) {
        }
    }

    fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, ShoppingWidgetProvider::class.java))
        if (ids.isNotEmpty()) ShoppingWidgetProvider().onUpdate(context, manager, ids)
    }

    fun launchIntent(context: Context, uri: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = LAUNCH_ACTION
            data = Uri.parse(uri)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun forwardToDart(context: Context, uri: Uri) {
        HomeWidgetBackgroundReceiver().onReceive(context,
            Intent(context, HomeWidgetBackgroundReceiver::class.java).setAction(BACKGROUND_ACTION).setData(uri))
    }
}

class ShoppingWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val snap = ShopData.load(context)
        for (id in ids) update(context, manager, snap, id)
        manager.notifyAppWidgetViewDataChanged(ids, R.id.shop_grid)
    }

    override fun onDeleted(context: Context, ids: IntArray) = ShopData.forget(context, ids)

    private fun update(context: Context, manager: AppWidgetManager, snap: ShopSnapshot, id: Int) {
        val views = RemoteViews(context.packageName, R.layout.widget_shopping)
        val list = ShopData.listFor(context, snap, id)
        val count = list?.let { snap.items[it.id]?.size } ?: 0
        views.setTextViewText(R.id.shop_title, if (list == null) "Einkaufsliste" else "${list.emoji} ${list.name}")
        views.setTextViewText(R.id.shop_count, if (count > 0) "$count" else "")
        list?.let { views.setInt(R.id.shop_title, "setTextColor", it.color) }
        val svc = Intent(context, ShoppingWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.shop_grid, svc)
        views.setEmptyView(R.id.shop_grid, R.id.shop_empty)
        // Vorlage für das Abhaken: der Artikel kommt per Fill-in-Intent
        views.setPendingIntentTemplate(R.id.shop_grid, PendingIntent.getBroadcast(context, id * 16 + 1,
            Intent(context, ShoppingCheckReceiver::class.java).setAction(ShopData.CHECK_ACTION),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE))
        val listParam = list?.id ?: ""
        views.setOnClickPendingIntent(R.id.shop_title, ShopData.launchIntent(context, "einkauf://list?list=$listParam", id * 16 + 2))
        views.setOnClickPendingIntent(R.id.shop_add, ShopData.launchIntent(context, "einkauf://add?list=$listParam", id * 16 + 3))
        views.setOnClickPendingIntent(R.id.shop_settings, PendingIntent.getActivity(context, id * 16 + 4,
            Intent(context, ShoppingWidgetConfigActivity::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                data = Uri.parse("einkauf-widget://config/$id")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        manager.updateAppWidget(id, views)
    }
}

class ShoppingWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        ShoppingFactory(applicationContext, intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, 0))
}

private class ShoppingFactory(private val context: Context, private val widgetId: Int) :
    RemoteViewsService.RemoteViewsFactory {
    private var entries: List<ShopEntry> = emptyList()
    private var color = 0xFF2F7D6B.toInt()

    override fun onCreate() {}
    override fun onDestroy() {}
    override fun onDataSetChanged() {
        val snap = ShopData.load(context)
        val list = ShopData.listFor(context, snap, widgetId)
        entries = list?.let { snap.items[it.id] } ?: emptyList()
        color = list?.color ?: color
    }

    override fun getCount() = entries.size
    override fun getViewTypeCount() = 1
    override fun getItemId(position: Int) = entries.getOrNull(position)?.id?.hashCode()?.toLong() ?: position.toLong()
    override fun hasStableIds() = true
    override fun getLoadingView(): RemoteViews? = null

    override fun getViewAt(position: Int): RemoteViews {
        val e = entries.getOrNull(position) ?: return RemoteViews(context.packageName, R.layout.widget_shopping_item)
        return RemoteViews(context.packageName, R.layout.widget_shopping_item).apply {
            setInt(R.id.tile_bg, "setColorFilter", color)
            setTextViewText(R.id.tile_emoji, e.emoji)
            setTextViewText(R.id.tile_name, e.name)
            setTextViewText(R.id.tile_spec, e.spec)
            setViewVisibility(R.id.tile_spec, if (e.spec.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE)
            setContentDescription(R.id.tile_root, "${e.name} abhaken")
            setOnClickFillInIntent(R.id.tile_root,
                Intent().setData(Uri.parse("einkauf://check?item=${Uri.encode(e.id)}")))
        }
    }
}

/** Antippen eines Artikels: sofort aus dem Widget nehmen, dann im Hintergrund (Dart) als gekauft speichern und abgleichen. */
class ShoppingCheckReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val uri = intent.data ?: return
        val itemId = uri.getQueryParameter("item") ?: return
        ShopData.removeLocally(context, itemId)
        ShopData.refreshAll(context)
        ShopData.forwardToDart(context, uri)
    }
}

/** Liste für genau dieses Widget wählen (oder der App folgen). */
class ShoppingWidgetConfigActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        widgetId = intent?.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
            ?: AppWidgetManager.INVALID_APPWIDGET_ID
        setResult(RESULT_CANCELED, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        title = "Liste für dieses Widget"
        val snap = ShopData.load(this)
        val chosen = ShopData.chosenList(this, widgetId)
        val dp = resources.displayMetrics.density
        fun px(v: Int) = (v * dp).toInt()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(px(20), px(8), px(20), px(12))
        }
        val group = RadioGroup(this)
        val follow = RadioButton(this).apply { text = "Immer die aktuelle Liste der App"; id = 1 }
        group.addView(follow)
        val ids = HashMap<Int, String>()
        snap.lists.forEachIndexed { i, l ->
            val rb = RadioButton(this).apply { text = "${l.emoji}  ${l.name}"; id = 100 + i }
            ids[rb.id] = l.id
            group.addView(rb)
        }
        group.check(ids.entries.firstOrNull { it.value == chosen }?.key ?: 1)
        if (snap.lists.isEmpty()) {
            root.addView(TextView(this).apply {
                text = "Noch keine Listen bekannt – bitte einmal die App öffnen."
                setPadding(0, px(8), 0, px(8))
            })
        }
        root.addView(group)
        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            setPadding(0, px(12), 0, 0)
        }
        buttons.addView(Button(this, null, android.R.attr.borderlessButtonStyle).apply {
            text = "Abbrechen"
            setOnClickListener { finish() }
        })
        buttons.addView(Button(this, null, android.R.attr.borderlessButtonStyle).apply {
            text = "Speichern"
            setOnClickListener {
                ShopData.choose(this@ShoppingWidgetConfigActivity, widgetId, ids[group.checkedRadioButtonId] ?: "")
                ShopData.refreshAll(this@ShoppingWidgetConfigActivity)
                setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
                finish()
            }
        })
        root.addView(buttons)
        setContentView(ScrollView(this).apply { addView(root) })
        window.setLayout((resources.displayMetrics.widthPixels * 0.9).toInt(), ViewGroup.LayoutParams.WRAP_CONTENT)
    }
}

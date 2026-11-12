package de.sweber.encrypted_shopping_app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Vor super.onCreate: dort wird die Flutter-Engine eingerichtet.
        if (savedInstanceState == null) pending = takeShared(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "einkauf/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "initial") {
                    result.success(pending)
                    pending = null
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = takeShared(intent) ?: return
        val ch = channel
        if (ch == null) pending = text else ch.invokeMethod("shared", text)
    }

    /** Text aus [ShareActivity]; danach als verbraucht markieren (kein erneutes Öffnen nach Neustart). */
    private fun takeShared(i: Intent?): String? {
        if (i?.action != ShareActivity.ACTION) return null
        val text = i.getStringExtra(Intent.EXTRA_TEXT)
        i.action = Intent.ACTION_MAIN
        return text?.takeIf { it.isNotBlank() }
    }
}

/**
 * Ziel im Android-Teilen-Menü („Auf die Einkaufsliste“). Reicht den Text an die
 * laufende App weiter (eigene Aufgabe, keine zweite App-Instanz) und schließt sich.
 */
class ShareActivity : Activity() {
    companion object {
        const val ACTION = "de.sweber.encrypted_shopping_app.SHARE"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val text = intent?.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
            ?: intent?.getStringExtra(Intent.EXTRA_SUBJECT) ?: ""
        if (intent?.action == Intent.ACTION_SEND && text.isNotBlank()) {
            startActivity(Intent(this, MainActivity::class.java).apply {
                action = ACTION
                putExtra(Intent.EXTRA_TEXT, text.take(20000))
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            })
        }
        finish()
    }
}

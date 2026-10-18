package app.nenures.nenures

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.PersistableBundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // P9: bloqueia captura e gravação de tela e oculta a prévia na tela de recentes.
        // Aplicado antes de qualquer conteúdo ser desenhado. Não impede fotos feitas
        // com outro aparelho nem um sistema modificado.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nenures/clipboard")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "copySensitive" -> {
                        val text = call.argument<String>("text")
                        if (text == null) {
                            result.error("bad_args", "texto ausente", null)
                        } else {
                            copySensitive(text)
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // D13: no Android 13+ o sistema oculta a prévia de conteúdo marcado como sensível.
    // Em versões anteriores, a cópia é comum (o aviso na interface continua valendo).
    private fun copySensitive(text: String) {
        val clip = ClipData.newPlainText("chave", text)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            clip.description.extras = PersistableBundle().apply {
                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
            }
        }
        val manager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        manager.setPrimaryClip(clip)
    }
}

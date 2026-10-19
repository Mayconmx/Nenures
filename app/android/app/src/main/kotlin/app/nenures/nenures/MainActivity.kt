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
                    "clearIfUnchanged" -> result.success(clearIfUnchanged())
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
        copiedAt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.primaryClipDescription?.timestamp ?: NONE
        } else {
            NONE
        }
    }

    // D13: apaga a chave copiada SÓ se a área de transferência ainda for a
    // mesma cópia. Compara o carimbo de tempo da descrição, sem ler o conteúdo
    // (ler faria o Android 12+ avisar que o app colou algo). Antes do Android 8
    // não há carimbo: nada é apagado, para nunca apagar algo copiado depois.
    private fun clearIfUnchanged(): Boolean {
        val expected = copiedAt
        copiedAt = NONE
        if (expected == NONE || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val current = manager.primaryClipDescription ?: return false
        if (current.timestamp != expected) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.clearPrimaryClip()
        } else {
            manager.setPrimaryClip(ClipData.newPlainText("", ""))
        }
        return true
    }

    private var copiedAt: Long = NONE

    private companion object {
        const val NONE = -1L
    }
}

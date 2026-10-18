package app.nenures.nenures

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

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
}

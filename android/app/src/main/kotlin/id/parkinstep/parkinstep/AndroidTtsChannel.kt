package id.parkinstep.parkinstep

import android.content.Context
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/**
 * Lightweight Indonesian TextToSpeech bridge for voice instructions and pre-flight accessibility.
 */
class AndroidTtsChannel(
    private val context: Context,
) : MethodChannel.MethodCallHandler, TextToSpeech.OnInitListener {
    private var tts: TextToSpeech? = null
    private var isReady = false
    private var pendingText: String? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "speak" -> {
                val text = call.argument<String>("text")?.trim().orEmpty()
                if (text.isNotEmpty()) {
                    speakText(text)
                }
                result.success(null)
            }

            "stop" -> {
                pendingText = null
                try {
                    tts?.stop()
                } catch (_: Exception) {
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) {
            isReady = false
            pendingText = null
            return
        }
        val engine = tts ?: return
        val idLocale = Locale("id", "ID")
        val langResult = engine.setLanguage(idLocale)
        if (langResult == TextToSpeech.LANG_MISSING_DATA ||
            langResult == TextToSpeech.LANG_NOT_SUPPORTED
        ) {
            engine.language = Locale.getDefault()
        }
        engine.setSpeechRate(0.92f)
        isReady = true
        val queued = pendingText
        pendingText = null
        if (!queued.isNullOrBlank()) {
            engine.speak(queued, TextToSpeech.QUEUE_FLUSH, null, "parkinstep_tts")
        }
    }

    private fun speakText(text: String) {
        if (tts == null) {
            pendingText = text
            tts = TextToSpeech(context.applicationContext, this)
            return
        }
        if (!isReady) {
            pendingText = text
            return
        }
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "parkinstep_tts")
    }

    fun shutdown() {
        pendingText = null
        isReady = false
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (_: Exception) {
        }
        tts = null
    }
}

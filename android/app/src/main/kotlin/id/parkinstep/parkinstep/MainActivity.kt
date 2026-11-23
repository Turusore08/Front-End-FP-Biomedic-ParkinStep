package id.parkinstep.parkinstep

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var videoExtractor: VideoFrameExtractor? = null
    private var ttsChannel: AndroidTtsChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val extractor = VideoFrameExtractor()
        val tts = AndroidTtsChannel(applicationContext)
        videoExtractor = extractor
        ttsChannel = tts

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.parkinstep.parkinstep/video_decoder",
        ).setMethodCallHandler(extractor)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.parkinstep.parkinstep/tts",
        ).setMethodCallHandler(tts)
    }

    override fun onDestroy() {
        videoExtractor?.closeAll()
        videoExtractor = null
        ttsChannel?.shutdown()
        ttsChannel = null
        super.onDestroy()
    }
}

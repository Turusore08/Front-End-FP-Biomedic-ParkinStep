package id.parkinstep.parkinstep

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var videoExtractor: VideoFrameExtractor? = null
    private var ttsChannel: AndroidTtsChannel? = null
    private var videoPlayerChannel: AndroidVideoPlayerChannel? = null
    private var skeletonVideoExporter: SkeletonVideoExporter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val extractor = VideoFrameExtractor()
        val tts = AndroidTtsChannel(applicationContext)
        val player = AndroidVideoPlayerChannel(flutterEngine.renderer)
        val exporter = SkeletonVideoExporter(applicationContext)

        videoExtractor = extractor
        ttsChannel = tts
        videoPlayerChannel = player
        skeletonVideoExporter = exporter

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.parkinstep.parkinstep/video_decoder",
        ).setMethodCallHandler(extractor)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.parkinstep.parkinstep/tts",
        ).setMethodCallHandler(tts)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.parkinstep.parkinstep/video_player",
        ).setMethodCallHandler(player)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "id.parkinstep.parkinstep/video_exporter",
        ).setMethodCallHandler(exporter)
    }

    override fun onDestroy() {
        videoExtractor?.closeAll()
        videoExtractor = null
        ttsChannel?.shutdown()
        ttsChannel = null
        videoPlayerChannel?.disposeAll()
        videoPlayerChannel = null
        skeletonVideoExporter?.shutdown()
        skeletonVideoExporter = null
        super.onDestroy()
    }
}

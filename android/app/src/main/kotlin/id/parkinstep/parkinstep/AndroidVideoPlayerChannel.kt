package id.parkinstep.parkinstep

import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Local MP4 texture playback bridge backed by Flutter's TextureRegistry.SurfaceProducer
 * and Android MediaPlayer for instant synchronized skeleton overlay rendering.
 */
class AndroidVideoPlayerChannel(
    private val textureRegistry: TextureRegistry,
) : MethodChannel.MethodCallHandler {
    private data class PlayerSession(
        val id: String,
        val mediaPlayer: MediaPlayer,
        val producer: TextureRegistry.SurfaceProducer,
        var durationMs: Int,
        var isCompleted: Boolean = false,
    )

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val sessions = ConcurrentHashMap<String, PlayerSession>()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "Video path is required.", null)
                    return
                }
                executor.execute { openInternal(path, result) }
            }

            "play" -> {
                val playerId = call.argument<String>("playerId")
                val session = playerId?.let { sessions[it] }
                if (session == null) {
                    result.error("NOT_FOUND", "Player session not found.", null)
                    return
                }
                try {
                    val mp = session.mediaPlayer
                    if (session.isCompleted ||
                        (session.durationMs > 0 && mp.currentPosition >= session.durationMs - 80)
                    ) {
                        seekCompat(mp, 0)
                    }
                    session.isCompleted = false
                    if (!mp.isPlaying) {
                        mp.start()
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("PLAY_FAILED", e.message, null)
                }
            }

            "pause" -> {
                val playerId = call.argument<String>("playerId")
                val session = playerId?.let { sessions[it] }
                if (session == null) {
                    result.success(null)
                    return
                }
                try {
                    if (session.mediaPlayer.isPlaying) {
                        session.mediaPlayer.pause()
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("PAUSE_FAILED", e.message, null)
                }
            }

            "seekTo" -> {
                val playerId = call.argument<String>("playerId")
                val posMs = call.argument<Int>("positionMs") ?: 0
                val session = playerId?.let { sessions[it] }
                if (session == null) {
                    result.success(null)
                    return
                }
                try {
                    val clamped = posMs.coerceIn(0, session.durationMs.coerceAtLeast(0))
                    session.isCompleted = false
                    seekCompat(session.mediaPlayer, clamped)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SEEK_FAILED", e.message, null)
                }
            }

            "getPosition" -> {
                val playerId = call.argument<String>("playerId")
                val session = playerId?.let { sessions[it] }
                if (session == null) {
                    result.success(
                        mapOf(
                            "positionMs" to 0,
                            "durationMs" to 0,
                            "isPlaying" to false,
                            "isCompleted" to false,
                        )
                    )
                    return
                }
                try {
                    val mp = session.mediaPlayer
                    val pos = if (session.isCompleted) {
                        session.durationMs
                    } else {
                        mp.currentPosition.coerceIn(0, session.durationMs.coerceAtLeast(0))
                    }
                    result.success(
                        mapOf(
                            "positionMs" to pos,
                            "durationMs" to session.durationMs,
                            "isPlaying" to mp.isPlaying,
                            "isCompleted" to session.isCompleted,
                        )
                    )
                } catch (_: Exception) {
                    result.success(
                        mapOf(
                            "positionMs" to 0,
                            "durationMs" to session.durationMs,
                            "isPlaying" to false,
                            "isCompleted" to false,
                        )
                    )
                }
            }

            "dispose" -> {
                val playerId = call.argument<String>("playerId")
                if (!playerId.isNullOrBlank()) {
                    sessions.remove(playerId)?.let(::releaseSession)
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun openInternal(path: String, result: MethodChannel.Result) {
        val file = File(path)
        if (!file.isFile) {
            mainHandler.post {
                result.error("FILE_NOT_FOUND", "Recorded video file does not exist.", null)
            }
            return
        }

        var metaWidth = 0
        var metaHeight = 0
        var metaDuration = 0
        var rotation = 0
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            metaWidth = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH
            )?.toIntOrNull() ?: 0
            metaHeight = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT
            )?.toIntOrNull() ?: 0
            metaDuration = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION
            )?.toIntOrNull() ?: 0
            rotation = normalizeRotation(
                retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION
                )?.toIntOrNull() ?: 0
            )
        } catch (_: Exception) {
        } finally {
            try {
                retriever.release()
            } catch (_: Exception) {
            }
        }

        mainHandler.post {
            var createdProducer: TextureRegistry.SurfaceProducer? = null
            var mediaPlayer: MediaPlayer? = null
            try {
                val producer = textureRegistry.createSurfaceProducer()
                createdProducer = producer
                if (metaWidth > 0 && metaHeight > 0) {
                    producer.setSize(metaWidth, metaHeight)
                }
                val id = UUID.randomUUID().toString()
                lateinit var session: PlayerSession
                mediaPlayer = MediaPlayer().apply {
                    setDataSource(path)
                    setSurface(producer.surface)
                    setVolume(0f, 0f)
                    setOnCompletionListener {
                        session.isCompleted = true
                    }
                    prepare()
                    val actualW = videoWidth.takeIf { it > 0 } ?: metaWidth.coerceAtLeast(320)
                    val actualH = videoHeight.takeIf { it > 0 } ?: metaHeight.coerceAtLeast(240)
                    producer.setSize(actualW, actualH)
                    seekCompat(this, 0)
                    metaWidth = actualW
                    metaHeight = actualH
                    metaDuration = duration.takeIf { it > 0 } ?: metaDuration
                }

                session = PlayerSession(
                    id = id,
                    mediaPlayer = mediaPlayer,
                    producer = producer,
                    durationMs = metaDuration.coerceAtLeast(0),
                )
                sessions[id] = session

                val swapped = rotation == 90 || rotation == 270
                val uprightW = if (swapped) metaHeight else metaWidth
                val uprightH = if (swapped) metaWidth else metaHeight

                result.success(
                    mapOf(
                        "playerId" to id,
                        "textureId" to producer.id().toInt(),
                        "uprightWidth" to uprightW.toDouble(),
                        "uprightHeight" to uprightH.toDouble(),
                        "durationMs" to session.durationMs,
                        "rotationDegrees" to rotation,
                        "handlesCropAndRotation" to producer.handlesCropAndRotation(),
                    )
                )
            } catch (e: Exception) {
                try {
                    mediaPlayer?.release()
                } catch (_: Exception) {
                }
                try {
                    createdProducer?.release()
                } catch (_: Exception) {
                }
                result.error("OPEN_FAILED", e.message ?: "Failed to open video player.", null)
            }
        }
    }

    private fun seekCompat(mp: MediaPlayer, positionMs: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            mp.seekTo(positionMs.toLong(), MediaPlayer.SEEK_CLOSEST)
        } else {
            mp.seekTo(positionMs)
        }
    }

    private fun normalizeRotation(degrees: Int): Int {
        val mod = ((degrees % 360) + 360) % 360
        return when (mod) {
            90, 180, 270 -> mod
            else -> 0
        }
    }

    private fun releaseSession(session: PlayerSession) {
        try {
            if (session.mediaPlayer.isPlaying) {
                session.mediaPlayer.stop()
            }
        } catch (_: Exception) {
        }
        try {
            session.mediaPlayer.release()
        } catch (_: Exception) {
        }
        mainHandler.post {
            try {
                session.producer.release()
            } catch (_: Exception) {
            }
        }
    }

    fun disposeAll() {
        val ids = sessions.keys.toList()
        for (id in ids) {
            sessions.remove(id)?.let(::releaseSession)
        }
        executor.shutdownNow()
    }
}

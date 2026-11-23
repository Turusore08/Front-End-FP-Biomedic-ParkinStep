package id.parkinstep.parkinstep

import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.graphics.Rect
import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Pull-based sequential Android video frame decoder for post-recording 15 Hz pose extraction.
 * Primary path decodes frames rapidly via MediaCodec (YUV_420_888), with automatic fallback to
 * MediaMetadataRetriever if the device codec does not expose Image planes.
 */
class VideoFrameExtractor : MethodChannel.MethodCallHandler {
    private data class DecoderSession(
        val id: String,
        val path: String,
        val stepUs: Long,
        val durationMs: Long,
        val rotationDegrees: Int,
        var extractor: MediaExtractor?,
        var codec: MediaCodec?,
        var retriever: MediaMetadataRetriever?,
        var useRetrieverFallback: Boolean = false,
        var inputDone: Boolean = false,
        var outputDone: Boolean = false,
        var nextTargetUs: Long = 0L,
        var emittedAnyFrame: Boolean = false,
    )

    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val sessions = ConcurrentHashMap<String, DecoderSession>()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openVideo" -> {
                val path = call.argument<String>("path")
                val targetFps = call.argument<Double>("targetFps") ?: 15.0
                if (path.isNullOrBlank()) {
                    postError(result, "INVALID_ARGS", "Video path is required.")
                    return
                }
                executor.execute {
                    try {
                        val opened = openVideoInternal(path, targetFps.coerceIn(1.0, 60.0))
                        postSuccess(result, opened)
                    } catch (e: Exception) {
                        postError(result, "VIDEO_OPEN_FAILED", e.message ?: "Failed to open video.")
                    }
                }
            }

            "nextFrame" -> {
                val decoderId = call.argument<String>("decoderId")
                if (decoderId.isNullOrBlank()) {
                    postError(result, "INVALID_ARGS", "decoderId is required.")
                    return
                }
                executor.execute {
                    try {
                        val frame = nextFrameInternal(decoderId)
                        postSuccess(result, frame)
                    } catch (e: Exception) {
                        postError(result, "VIDEO_DECODE_FAILED", e.message ?: "Failed to decode frame.")
                    }
                }
            }

            "closeVideo" -> {
                val decoderId = call.argument<String>("decoderId")
                executor.execute {
                    if (!decoderId.isNullOrBlank()) {
                        sessions.remove(decoderId)?.let(::releaseSession)
                    }
                    postSuccess(result, null)
                }
            }

            else -> result.notImplemented()
        }
    }

    fun closeAll() {
        val ids = sessions.keys.toList()
        for (id in ids) {
            sessions.remove(id)?.let(::releaseSession)
        }
        executor.shutdownNow()
    }

    private fun openVideoInternal(path: String, targetFps: Double): Map<String, Any> {
        val file = File(path)
        if (!file.isFile) {
            throw IllegalArgumentException("Recorded video file does not exist.")
        }

        val retriever = MediaMetadataRetriever()
        var durationMs = 0L
        var rotationDegrees = 0
        try {
            retriever.setDataSource(path)
            durationMs = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION
            )?.toLongOrNull() ?: 0L
            rotationDegrees = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION
            )?.toIntOrNull() ?: 0
        } catch (_: Exception) {
            // Will inspect MediaFormat below if metadata retrieval partially fails.
        }

        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        var useRetrieverFallback = false

        try {
            extractor.setDataSource(path)
            val videoTrackIndex = findVideoTrack(extractor)
            if (videoTrackIndex < 0) {
                throw IllegalStateException("No video track found in file.")
            }
            extractor.selectTrack(videoTrackIndex)
            val format = extractor.getTrackFormat(videoTrackIndex)
            if (durationMs <= 0L && format.containsKey(MediaFormat.KEY_DURATION)) {
                durationMs = format.getLong(MediaFormat.KEY_DURATION) / 1000L
            }
            if (rotationDegrees == 0 && format.containsKey(MediaFormat.KEY_ROTATION)) {
                rotationDegrees = format.getInteger(MediaFormat.KEY_ROTATION)
            }

            val mime = format.getString(MediaFormat.KEY_MIME)
                ?: throw IllegalStateException("Video track missing MIME type.")
            format.setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
            )
            codec = MediaCodec.createDecoderByType(mime).apply {
                configure(format, null, null, 0)
                start()
            }
        } catch (_: Exception) {
            try {
                codec?.release()
            } catch (_: Exception) {
            }
            codec = null
            try {
                extractor.release()
            } catch (_: Exception) {
            }
            useRetrieverFallback = true
        }

        val stepUs = max(1L, (1_000_000.0 / targetFps).roundToInt().toLong())
        val estimatedFrames = if (durationMs > 0L) {
            max(1, ((durationMs / 1000.0) * targetFps).toInt())
        } else {
            1
        }
        val id = UUID.randomUUID().toString()
        val session = DecoderSession(
            id = id,
            path = path,
            stepUs = stepUs,
            durationMs = durationMs,
            rotationDegrees = normalizeRotation(rotationDegrees),
            extractor = if (useRetrieverFallback) null else extractor,
            codec = codec,
            retriever = retriever,
            useRetrieverFallback = useRetrieverFallback,
        )
        sessions[id] = session

        return mapOf(
            "decoderId" to id,
            "durationMs" to durationMs.toInt(),
            "estimatedFrames" to estimatedFrames,
            "rotationDegrees" to session.rotationDegrees,
        )
    }

    private fun nextFrameInternal(decoderId: String): Map<String, Any>? {
        val session = sessions[decoderId] ?: return null
        if (session.useRetrieverFallback) {
            return extractRetrieverFrame(session)
        }
        val codec = session.codec ?: return extractRetrieverFrame(session)
        val extractor = session.extractor ?: return extractRetrieverFrame(session)
        if (session.outputDone) {
            return null
        }

        val info = MediaCodec.BufferInfo()
        var iterations = 0
        while (!session.outputDone && iterations < 2400) {
            iterations++
            if (!session.inputDone) {
                val inIndex = codec.dequeueInputBuffer(10_000)
                if (inIndex >= 0) {
                    val inputBuffer = codec.getInputBuffer(inIndex)
                    if (inputBuffer != null) {
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(
                                inIndex,
                                0,
                                0,
                                0L,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            session.inputDone = true
                        } else {
                            val sampleTimeUs = extractor.sampleTime
                            codec.queueInputBuffer(inIndex, 0, sampleSize, sampleTimeUs, 0)
                            extractor.advance()
                        }
                    }
                }
            }

            val outIndex = codec.dequeueOutputBuffer(info, 10_000)
            if (outIndex >= 0) {
                val isEos = (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                if (info.size > 0 && info.presentationTimeUs >= session.nextTargetUs) {
                    var image: Image? = null
                    try {
                        image = codec.getOutputImage(outIndex)
                        if (image == null || image.format != ImageFormat.YUV_420_888) {
                            // Switch cleanly to retriever fallback if codec hides YUV planes.
                            if (!session.emittedAnyFrame) {
                                session.useRetrieverFallback = true
                            } else {
                                session.outputDone = isEos
                                continue
                            }
                        } else {
                            val packed = packYuvImage(
                                image = image,
                                rotationDegrees = session.rotationDegrees,
                                ptsUs = info.presentationTimeUs,
                            )
                            session.emittedAnyFrame = true
                            session.nextTargetUs = max(
                                session.nextTargetUs + session.stepUs,
                                info.presentationTimeUs + (session.stepUs / 2L),
                            )
                            if (isEos) {
                                session.outputDone = true
                            }
                            return packed
                        }
                    } finally {
                        try {
                            image?.close()
                        } catch (_: Exception) {
                        }
                        codec.releaseOutputBuffer(outIndex, false)
                    }

                    if (session.useRetrieverFallback) {
                        releaseCodecOnly(session)
                        return extractRetrieverFrame(session)
                    }
                } else {
                    codec.releaseOutputBuffer(outIndex, false)
                    if (isEos) {
                        session.outputDone = true
                        return null
                    }
                }
            }
        }
        return null
    }

    private fun extractRetrieverFrame(session: DecoderSession): Map<String, Any>? {
        val retriever = session.retriever ?: return null
        val maxUs = if (session.durationMs > 0L) session.durationMs * 1000L else 0L
        if (session.emittedAnyFrame && session.nextTargetUs > maxUs) {
            return null
        }

        val bitmap = retriever.getFrameAtTime(
            session.nextTargetUs,
            MediaMetadataRetriever.OPTION_CLOSEST_SYNC,
        ) ?: return null

        val prepared = ensureEvenSizedScaledBitmap(bitmap, maxSide = 640)
        try {
            val w = prepared.width
            val h = prepared.height
            if (w < 2 || h < 2) return null

            val argb = IntArray(w * h)
            prepared.getPixels(argb, 0, w, 0, 0, w, h)
            val yBytes = ByteArray(w * h)
            val uBytes = ByteArray((w / 2) * (h / 2))
            val vBytes = ByteArray((w / 2) * (h / 2))
            argbToYuv420(argb, w, h, yBytes, uBytes, vBytes)

            val ptsUs = session.nextTargetUs
            session.emittedAnyFrame = true
            session.nextTargetUs += session.stepUs

            // MediaMetadataRetriever returns an upright bitmap already rotated by metadata.
            return mapOf(
                "width" to w,
                "height" to h,
                "yBytes" to yBytes,
                "uBytes" to uBytes,
                "vBytes" to vBytes,
                "yRowStride" to w,
                "uvRowStride" to (w / 2),
                "uvPixelStride" to 1,
                "rotationDegrees" to 0,
                "timestampMs" to (ptsUs / 1000L).toInt(),
            )
        } finally {
            if (prepared !== bitmap) {
                prepared.recycle()
            }
            bitmap.recycle()
        }
    }

    private fun packYuvImage(
        image: Image,
        rotationDegrees: Int,
        ptsUs: Long,
    ): Map<String, Any> {
        val rawCrop: Rect = image.cropRect
        val cropLeft = (rawCrop.left.coerceIn(0, image.width - 2)) and 1.inv()
        val cropTop = (rawCrop.top.coerceIn(0, image.height - 2)) and 1.inv()
        val rawW = if (rawCrop.width() > 0) rawCrop.width() else image.width
        val rawH = if (rawCrop.height() > 0) rawCrop.height() else image.height
        val w = (rawW.coerceAtMost(image.width - cropLeft) and 1.inv()).coerceAtLeast(2)
        val h = (rawH.coerceAtMost(image.height - cropTop) and 1.inv()).coerceAtLeast(2)

        val planes = image.planes
        val yPlane = planes[0]
        val uPlane = planes[1]
        val vPlane = planes[2]

        val yBytes = ByteArray(w * h)
        val yBuf = yPlane.buffer
        val yRowStride = yPlane.rowStride
        val yPixStride = yPlane.pixelStride
        if (yPixStride == 1 && yRowStride == w && cropLeft == 0 && cropTop == 0) {
            yBuf.position(0)
            yBuf.get(yBytes, 0, w * h)
        } else {
            for (r in 0 until h) {
                val srcRowOffset = (cropTop + r) * yRowStride + cropLeft * yPixStride
                if (yPixStride == 1) {
                    yBuf.position(srcRowOffset)
                    yBuf.get(yBytes, r * w, w)
                } else {
                    val dstOffset = r * w
                    for (c in 0 until w) {
                        yBytes[dstOffset + c] = yBuf.get(srcRowOffset + c * yPixStride)
                    }
                }
            }
        }

        val cw = w / 2
        val ch = h / 2
        val uvLen = cw * ch
        val uBytes = ByteArray(uvLen)
        val vBytes = ByteArray(uvLen)
        copyChromaPlane(
            plane = uPlane,
            cropLeft = cropLeft / 2,
            cropTop = cropTop / 2,
            cw = cw,
            ch = ch,
            out = uBytes,
        )
        copyChromaPlane(
            plane = vPlane,
            cropLeft = cropLeft / 2,
            cropTop = cropTop / 2,
            cw = cw,
            ch = ch,
            out = vBytes,
        )

        return mapOf(
            "width" to w,
            "height" to h,
            "yBytes" to yBytes,
            "uBytes" to uBytes,
            "vBytes" to vBytes,
            "yRowStride" to w,
            "uvRowStride" to cw,
            "uvPixelStride" to 1,
            "rotationDegrees" to rotationDegrees,
            "timestampMs" to (ptsUs / 1000L).toInt(),
        )
    }

    private fun copyChromaPlane(
        plane: Image.Plane,
        cropLeft: Int,
        cropTop: Int,
        cw: Int,
        ch: Int,
        out: ByteArray,
    ) {
        val buf = plane.buffer
        val rowStride = plane.rowStride
        val pixStride = plane.pixelStride
        if (pixStride == 1 && rowStride == cw && cropLeft == 0 && cropTop == 0) {
            buf.position(0)
            buf.get(out, 0, cw * ch)
            return
        }
        for (r in 0 until ch) {
            val srcRow = (cropTop + r) * rowStride + cropLeft * pixStride
            val dstRow = r * cw
            if (pixStride == 1) {
                buf.position(srcRow)
                buf.get(out, dstRow, cw)
            } else {
                for (c in 0 until cw) {
                    out[dstRow + c] = buf.get(srcRow + c * pixStride)
                }
            }
        }
    }

    private fun ensureEvenSizedScaledBitmap(src: Bitmap, maxSide: Int): Bitmap {
        val longest = max(src.width, src.height)
        val scale = if (longest > maxSide) maxSide.toDouble() / longest.toDouble() else 1.0
        val targetW = ((src.width * scale).roundToInt() and 1.inv()).coerceAtLeast(2)
        val targetH = ((src.height * scale).roundToInt() and 1.inv()).coerceAtLeast(2)
        if (targetW == src.width && targetH == src.height) {
            return src
        }
        return Bitmap.createScaledBitmap(src, targetW, targetH, true)
    }

    private fun argbToYuv420(
        argb: IntArray,
        width: Int,
        height: Int,
        yOut: ByteArray,
        uOut: ByteArray,
        vOut: ByteArray,
    ) {
        val cw = width / 2
        for (row in 0 until height) {
            val rowBase = row * width
            val uvRowBase = (row shr 1) * cw
            for (col in 0 until width) {
                val px = argb[rowBase + col]
                val r = (px shr 16) and 0xFF
                val g = (px shr 8) and 0xFF
                val b = px and 0xFF
                val yVal = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                yOut[rowBase + col] = yVal.coerceIn(0, 255).toByte()
                if ((row and 1) == 0 && (col and 1) == 0) {
                    val uVal = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val vVal = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    val uvIndex = uvRowBase + (col shr 1)
                    uOut[uvIndex] = uVal.coerceIn(0, 255).toByte()
                    vOut[uvIndex] = vVal.coerceIn(0, 255).toByte()
                }
            }
        }
    }

    private fun findVideoTrack(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME)
            if (mime != null && mime.startsWith("video/")) {
                return i
            }
        }
        return -1
    }

    private fun normalizeRotation(degrees: Int): Int {
        val mod = ((degrees % 360) + 360) % 360
        return when (mod) {
            90, 180, 270 -> mod
            else -> 0
        }
    }

    private fun releaseCodecOnly(session: DecoderSession) {
        try {
            session.codec?.stop()
        } catch (_: Exception) {
        }
        try {
            session.codec?.release()
        } catch (_: Exception) {
        }
        session.codec = null
        try {
            session.extractor?.release()
        } catch (_: Exception) {
        }
        session.extractor = null
    }

    private fun releaseSession(session: DecoderSession) {
        releaseCodecOnly(session)
        try {
            session.retriever?.release()
        } catch (_: Exception) {
        }
        session.retriever = null
    }

    private fun postSuccess(result: MethodChannel.Result, value: Any?) {
        mainHandler.post { result.success(value) }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String) {
        mainHandler.post { result.error(code, message, null) }
    }
}

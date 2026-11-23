package id.parkinstep.parkinstep

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.view.Surface
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Pure Android SDK (MediaCodec + MediaMuxer + Canvas, zero FFmpeg) exporter that
 * renders a standalone MP4 video with synchronized 17-COCO skeleton overlays and
 * saves it to Movies/ParkinStep via MediaStore.
 */
class SkeletonVideoExporter(
    private val context: Context,
) : MethodChannel.MethodCallHandler {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private val UPPER_BONES = arrayOf(
            intArrayOf(0, 1),
            intArrayOf(0, 2),
            intArrayOf(1, 3),
            intArrayOf(2, 4),
            intArrayOf(5, 6),
            intArrayOf(5, 7),
            intArrayOf(7, 9),
            intArrayOf(6, 8),
            intArrayOf(8, 10),
            intArrayOf(5, 11),
            intArrayOf(6, 12),
        )
        private val LB6_BONES = arrayOf(
            intArrayOf(11, 12),
            intArrayOf(11, 13),
            intArrayOf(13, 15),
            intArrayOf(12, 14),
            intArrayOf(14, 16),
        )
        private val LB6_JOINTS = intArrayOf(11, 12, 13, 14, 15, 16)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAppFilesDir" -> {
                result.success(context.filesDir.absolutePath)
            }

            "exportSkeletonVideo" -> {
                val sourceVideoPath = call.argument<String>("sourceVideoPath")
                val sessionId = call.argument<String>("sessionId") ?: "session"
                val srcWidth = call.argument<Double>("srcWidth") ?: 480.0
                val srcHeight = call.argument<Double>("srcHeight") ?: 640.0
                val timestampsMs = call.argument<IntArray>("timestampsMs") ?: IntArray(0)
                val fogFlags = call.argument<ByteArray>("fogFlags") ?: ByteArray(0)
                val keypointsFlat = call.argument<FloatArray>("keypointsFlat") ?: FloatArray(0)
                val targetFps = (call.argument<Int>("targetFps") ?: 15).coerceIn(5, 30)

                if (sourceVideoPath.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "sourceVideoPath is required.", null)
                    return
                }

                executor.execute {
                    try {
                        val exported = exportInternal(
                            sourceVideoPath = sourceVideoPath,
                            sessionId = sessionId,
                            srcWidth = srcWidth,
                            srcHeight = srcHeight,
                            timestampsMs = timestampsMs,
                            fogFlags = fogFlags,
                            keypointsFlat = keypointsFlat,
                            targetFps = targetFps,
                        )
                        mainHandler.post { result.success(exported) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("EXPORT_FAILED", e.message ?: "Failed to export MP4.", null)
                        }
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    fun shutdown() {
        executor.shutdownNow()
    }

    private fun exportInternal(
        sourceVideoPath: String,
        sessionId: String,
        srcWidth: Double,
        srcHeight: Double,
        timestampsMs: IntArray,
        fogFlags: ByteArray,
        keypointsFlat: FloatArray,
        targetFps: Int,
    ): Map<String, Any> {
        val srcFile = File(sourceVideoPath)
        if (!srcFile.isFile) {
            throw IllegalArgumentException("Source recorded video file not found.")
        }

        val retriever = MediaMetadataRetriever()
        var metaW = srcWidth.roundToInt().coerceAtLeast(160)
        var metaH = srcHeight.roundToInt().coerceAtLeast(160)
        var rotationDegrees = 0
        var durationMs = 0L
        try {
            retriever.setDataSource(sourceVideoPath)
            val rw = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH
            )?.toIntOrNull() ?: 0
            val rh = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT
            )?.toIntOrNull() ?: 0
            rotationDegrees = normalizeRotation(
                retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION
                )?.toIntOrNull() ?: 0
            )
            durationMs = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION
            )?.toLongOrNull() ?: 0L
            if (rw > 0 && rh > 0) {
                val swapped = rotationDegrees == 90 || rotationDegrees == 270
                metaW = if (swapped) rh else rw
                metaH = if (swapped) rw else rh
            }
        } catch (_: Exception) {
        }

        val longest = max(metaW, metaH).coerceAtLeast(1)
        val scale = if (longest > 640) 640.0 / longest.toDouble() else 1.0
        val outW = (((metaW * scale).roundToInt() + 8) / 16 * 16).coerceIn(160, 640)
        val outH = (((metaH * scale).roundToInt() + 8) / 16 * 16).coerceIn(160, 640)

        val tempOutFile = File(context.cacheDir, "parkinstep_export_${System.currentTimeMillis()}.mp4")
        var encoder: MediaCodec? = null
        var inputSurface: Surface? = null
        var muxer: MediaMuxer? = null
        var decoder: MediaCodec? = null
        var extractor: MediaExtractor? = null
        var muxerStarted = false
        var muxerTrackIndex = -1

        try {
            val encFormat = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, outW, outH).apply {
                setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface,
                )
                setInteger(MediaFormat.KEY_BIT_RATE, 1_500_000)
                setInteger(MediaFormat.KEY_FRAME_RATE, targetFps)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
            }
            encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).apply {
                configure(encFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            }
            inputSurface = encoder.createInputSurface()
            encoder.start()
            muxer = MediaMuxer(tempOutFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            val stepUs = max(1L, (1_000_000.0 / targetFps).roundToInt().toLong())
            var nextTargetUs = 0L
            var encodedFrames = 0L
            var muxedSamples = 0L

            var useRetriever = false
            try {
                extractor = MediaExtractor()
                extractor.setDataSource(sourceVideoPath)
                val trackIdx = findVideoTrack(extractor)
                if (trackIdx < 0) throw IllegalStateException("No video track.")
                extractor.selectTrack(trackIdx)
                val trackFmt = extractor.getTrackFormat(trackIdx)
                if (durationMs <= 0L && trackFmt.containsKey(MediaFormat.KEY_DURATION)) {
                    durationMs = trackFmt.getLong(MediaFormat.KEY_DURATION) / 1000L
                }
                val mime = trackFmt.getString(MediaFormat.KEY_MIME)
                    ?: throw IllegalStateException("Missing video MIME.")
                trackFmt.setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
                )
                decoder = MediaCodec.createDecoderByType(mime).apply {
                    configure(trackFmt, null, null, 0)
                    start()
                }
            } catch (_: Exception) {
                try {
                    decoder?.release()
                } catch (_: Exception) {
                }
                decoder = null
                try {
                    extractor?.release()
                } catch (_: Exception) {
                }
                extractor = null
                useRetriever = true
            }

            fun drainEncoder(endOfStream: Boolean) {
                val enc = encoder ?: return
                val mux = muxer ?: return
                if (endOfStream) {
                    enc.signalEndOfInputStream()
                }
                val encInfo = MediaCodec.BufferInfo()
                var tries = 0
                while (tries < 600) {
                    tries++
                    val outIdx = enc.dequeueOutputBuffer(encInfo, 5_000)
                    if (outIdx == MediaCodec.INFO_TRY_AGAIN_LATER) {
                        if (!endOfStream) break
                    } else if (outIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        if (!muxerStarted) {
                            muxerTrackIndex = mux.addTrack(enc.outputFormat)
                            mux.start()
                            muxerStarted = true
                        }
                    } else if (outIdx >= 0) {
                        val encodedData = enc.getOutputBuffer(outIdx)
                        if (encodedData != null && (encInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) == 0 && encInfo.size > 0 && muxerStarted) {
                            encodedData.position(encInfo.offset)
                            encodedData.limit(encInfo.offset + encInfo.size)
                            val sampleInfo = MediaCodec.BufferInfo().apply {
                                set(encInfo.offset, encInfo.size, muxedSamples * stepUs, encInfo.flags)
                            }
                            mux.writeSampleData(muxerTrackIndex, encodedData, sampleInfo)
                            muxedSamples++
                        }
                        val eos = (encInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                        enc.releaseOutputBuffer(outIdx, false)
                        if (eos) break
                    }
                }
            }

            fun renderFrameToEncoder(uprightBmp: Bitmap, ptsMs: Int) {
                val surf = inputSurface ?: return
                val canvas = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    surf.lockHardwareCanvas()
                } else {
                    surf.lockCanvas(null)
                }
                try {
                    drawAnnotatedFrame(
                        canvas = canvas,
                        bitmap = uprightBmp,
                        outW = outW,
                        outH = outH,
                        srcW = srcWidth,
                        srcH = srcHeight,
                        ptsMs = ptsMs,
                        timestampsMs = timestampsMs,
                        fogFlags = fogFlags,
                        keypointsFlat = keypointsFlat,
                    )
                } finally {
                    surf.unlockCanvasAndPost(canvas)
                }
                encodedFrames++
                drainEncoder(false)
            }

            if (!useRetriever && decoder != null && extractor != null) {
                val info = MediaCodec.BufferInfo()
                var inputDone = false
                var outputDone = false
                var iterations = 0
                while (!outputDone && iterations < 10_000) {
                    iterations++
                    if (!inputDone) {
                        val inIdx = decoder.dequeueInputBuffer(10_000)
                        if (inIdx >= 0) {
                            val buf = decoder.getInputBuffer(inIdx)
                            if (buf != null) {
                                val size = extractor.readSampleData(buf, 0)
                                if (size < 0) {
                                    decoder.queueInputBuffer(inIdx, 0, 0, 0L, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                    inputDone = true
                                } else {
                                    decoder.queueInputBuffer(inIdx, 0, size, extractor.sampleTime, 0)
                                    extractor.advance()
                                }
                            }
                        }
                    }

                    val outIdx = decoder.dequeueOutputBuffer(info, 10_000)
                    if (outIdx >= 0) {
                        val isEos = (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0
                        if (info.size > 0 && info.presentationTimeUs >= nextTargetUs) {
                            var img: Image? = null
                            try {
                                img = decoder.getOutputImage(outIdx)
                                if (img != null && img.format == ImageFormat.YUV_420_888) {
                                    val bmp = yuvImageToUprightBitmap(img, rotationDegrees)
                                    try {
                                        renderFrameToEncoder(bmp, (info.presentationTimeUs / 1000L).toInt())
                                    } finally {
                                        bmp.recycle()
                                    }
                                    nextTargetUs = max(nextTargetUs + stepUs, info.presentationTimeUs + (stepUs / 2L))
                                } else if (encodedFrames == 0L) {
                                    useRetriever = true
                                }
                            } finally {
                                try {
                                    img?.close()
                                } catch (_: Exception) {
                                }
                                decoder.releaseOutputBuffer(outIdx, false)
                            }
                            if (useRetriever) break
                        } else {
                            decoder.releaseOutputBuffer(outIdx, false)
                        }
                        if (isEos) outputDone = true
                    }
                }
            }

            if (useRetriever) {
                val maxUs = if (durationMs > 0L) durationMs * 1000L else 0L
                var curUs = encodedFrames * stepUs
                while (curUs <= maxUs || (maxUs == 0L && encodedFrames == 0L)) {
                    val bmp = retriever.getFrameAtTime(curUs, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                        ?: break
                    try {
                        renderFrameToEncoder(bmp, (curUs / 1000L).toInt())
                    } finally {
                        bmp.recycle()
                    }
                    curUs += stepUs
                    if (maxUs == 0L) break
                }
            }

            drainEncoder(true)
        } finally {
            try {
                decoder?.stop()
            } catch (_: Exception) {
            }
            try {
                decoder?.release()
            } catch (_: Exception) {
            }
            try {
                extractor?.release()
            } catch (_: Exception) {
            }
            try {
                retriever.release()
            } catch (_: Exception) {
            }
            try {
                encoder?.stop()
            } catch (_: Exception) {
            }
            try {
                encoder?.release()
            } catch (_: Exception) {
            }
            try {
                inputSurface?.release()
            } catch (_: Exception) {
            }
            if (muxerStarted) {
                try {
                    muxer?.stop()
                } catch (_: Exception) {
                }
            }
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
        }

        return try {
            publishExportedMp4(tempOutFile, sessionId)
        } finally {
            if (tempOutFile.exists()) {
                tempOutFile.delete()
            }
        }
    }

    private fun drawAnnotatedFrame(
        canvas: Canvas,
        bitmap: Bitmap,
        outW: Int,
        outH: Int,
        srcW: Double,
        srcH: Double,
        ptsMs: Int,
        timestampsMs: IntArray,
        fogFlags: ByteArray,
        keypointsFlat: FloatArray,
    ) {
        canvas.drawBitmap(bitmap, null, Rect(0, 0, outW, outH), null)

        if (timestampsMs.isEmpty() || keypointsFlat.size < 51) return
        val idx = findNearestFrameIndex(timestampsMs, ptsMs)
        val base = idx * 51
        if (base + 50 >= keypointsFlat.size) return

        val isFog = idx < fogFlags.size && fogFlags[idx] != 0.toByte()
        val lb6Color = if (isFog) Color.rgb(220, 38, 38) else Color.rgb(34, 211, 153)
        val scaleX = if (srcW > 0.0) outW.toFloat() / srcW.toFloat() else 1f
        val scaleY = if (srcH > 0.0) outH.toFloat() / srcH.toFloat() else 1f

        val upperPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(210, 56, 189, 248)
            strokeWidth = 3f
            strokeCap = Paint.Cap.ROUND
            style = Paint.Style.STROKE
        }
        val upperJointPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(56, 189, 248)
            style = Paint.Style.FILL
        }
        val lb6Paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = lb6Color
            strokeWidth = 6f
            strokeCap = Paint.Cap.ROUND
            style = Paint.Style.STROKE
        }
        val outerDotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        val innerDotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = lb6Color
            style = Paint.Style.FILL
        }

        fun valid(joint: Int): Boolean = keypointsFlat[base + joint * 3 + 2] >= 0.20f
        fun px(joint: Int): Float = keypointsFlat[base + joint * 3] * scaleX
        fun py(joint: Int): Float = keypointsFlat[base + joint * 3 + 1] * scaleY

        for (pair in UPPER_BONES) {
            val a = pair[0]
            val b = pair[1]
            if (valid(a) && valid(b)) {
                canvas.drawLine(px(a), py(a), px(b), py(b), upperPaint)
            }
        }
        for (j in 0..10) {
            if (valid(j)) {
                canvas.drawCircle(px(j), py(j), 3.5f, upperJointPaint)
            }
        }
        for (pair in LB6_BONES) {
            val a = pair[0]
            val b = pair[1]
            if (valid(a) && valid(b)) {
                canvas.drawLine(px(a), py(a), px(b), py(b), lb6Paint)
            }
        }
        for (j in LB6_JOINTS) {
            if (valid(j)) {
                val x = px(j)
                val y = py(j)
                canvas.drawCircle(x, y, 7f, outerDotPaint)
                canvas.drawCircle(x, y, 4.8f, innerDotPaint)
            }
        }

        val badgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (isFog) Color.argb(230, 220, 38, 38) else Color.argb(215, 6, 95, 70)
            style = Paint.Style.FILL
        }
        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = max(18f, outW * 0.036f)
            isFakeBoldText = true
        }
        val label = if (isFog) "ParkinStep · FoG" else "ParkinStep · Normal"
        val textW = textPaint.measureText(label)
        val badgeRect = RectF(14f, 14f, 34f + textW, 24f + textPaint.textSize + 10f)
        canvas.drawRoundRect(badgeRect, 14f, 14f, badgePaint)
        canvas.drawText(label, 24f, 20f + textPaint.textSize, textPaint)
    }

    private fun findNearestFrameIndex(timestampsMs: IntArray, targetMs: Int): Int {
        if (targetMs <= timestampsMs[0]) return 0
        val last = timestampsMs.size - 1
        if (targetMs >= timestampsMs[last]) return last
        var lo = 0
        var hi = last
        while (lo <= hi) {
            val mid = (lo + hi) ushr 1
            val t = timestampsMs[mid]
            if (t == targetMs) return mid
            if (t < targetMs) lo = mid + 1 else hi = mid - 1
        }
        val dLo = abs(timestampsMs[lo] - targetMs)
        val dHi = abs(targetMs - timestampsMs[hi])
        return if (dLo < dHi) lo else hi
    }

    private fun yuvImageToUprightBitmap(image: Image, rotationDegrees: Int): Bitmap {
        val rawCrop = image.cropRect
        val cropLeft = (rawCrop.left.coerceIn(0, image.width - 2)) and 1.inv()
        val cropTop = (rawCrop.top.coerceIn(0, image.height - 2)) and 1.inv()
        val rawW = if (rawCrop.width() > 0) rawCrop.width() else image.width
        val rawH = if (rawCrop.height() > 0) rawCrop.height() else image.height
        val w = (rawW.coerceAtMost(image.width - cropLeft) and 1.inv()).coerceAtLeast(2)
        val h = (rawH.coerceAtMost(image.height - cropTop) and 1.inv()).coerceAtLeast(2)

        val planes = image.planes
        val yBuf = planes[0].buffer
        val uBuf = planes[1].buffer
        val vBuf = planes[2].buffer
        val yRowStride = planes[0].rowStride
        val yPixStride = planes[0].pixelStride
        val uRowStride = planes[1].rowStride
        val uPixStride = planes[1].pixelStride
        val vRowStride = planes[2].rowStride
        val vPixStride = planes[2].pixelStride

        val argb = IntArray(w * h)
        for (r in 0 until h) {
            val sy = cropTop + r
            val uvRow = (sy shr 1)
            val yRowOffset = sy * yRowStride
            val uRowOffset = uvRow * uRowStride
            val vRowOffset = uvRow * vRowStride
            val outRow = r * w
            for (c in 0 until w) {
                val sx = cropLeft + c
                val yVal = yBuf.get(yRowOffset + sx * yPixStride).toInt() and 0xFF
                val uvCol = sx shr 1
                val uVal = (uBuf.get(uRowOffset + uvCol * uPixStride).toInt() and 0xFF) - 128
                val vVal = (vBuf.get(vRowOffset + uvCol * vPixStride).toInt() and 0xFF) - 128
                val cY = (yVal - 16).coerceAtLeast(0)
                val rPx = (298 * cY + 409 * vVal + 128) shr 8
                val gPx = (298 * cY - 100 * uVal - 208 * vVal + 128) shr 8
                val bPx = (298 * cY + 516 * uVal + 128) shr 8
                argb[outRow + c] = Color.rgb(
                    rPx.coerceIn(0, 255),
                    gPx.coerceIn(0, 255),
                    bPx.coerceIn(0, 255),
                )
            }
        }

        val rawBmp = Bitmap.createBitmap(argb, w, h, Bitmap.Config.ARGB_8888)
        if (rotationDegrees == 0) return rawBmp
        val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
        return try {
            Bitmap.createBitmap(rawBmp, 0, 0, w, h, matrix, false)
        } finally {
            rawBmp.recycle()
        }
    }

    private fun publishExportedMp4(tempFile: File, sessionId: String): Map<String, Any> {
        val safeId = sessionId.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        val fileName = "parkinstep_skeleton_$safeId.mp4"
        val sizeBytes = tempFile.length().toInt()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                put(
                    MediaStore.Video.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_MOVIES}/ParkinStep",
                )
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
            if (uri != null) {
                try {
                    resolver.openOutputStream(uri)?.use { out ->
                        FileInputStream(tempFile).use { input ->
                            input.copyTo(out)
                        }
                    } ?: throw IllegalStateException("Cannot open MediaStore output stream.")
                    values.clear()
                    values.put(MediaStore.Video.Media.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)
                    return mapOf(
                        "savedPath" to "Movies/ParkinStep/$fileName",
                        "gallerySaved" to true,
                        "sizeBytes" to sizeBytes,
                    )
                } catch (_: Exception) {
                    try {
                        resolver.delete(uri, null, null)
                    } catch (_: Exception) {
                    }
                }
            }
        }

        val fallbackDir = context.getExternalFilesDir(Environment.DIRECTORY_MOVIES)
            ?: File(context.filesDir, "exports")
        if (!fallbackDir.exists()) {
            fallbackDir.mkdirs()
        }
        val destFile = File(fallbackDir, fileName)
        tempFile.copyTo(destFile, overwrite = true)
        return mapOf(
            "savedPath" to destFile.absolutePath,
            "gallerySaved" to false,
            "sizeBytes" to sizeBytes,
        )
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
}

package __PKG__

import android.content.ContentValues
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import com.google.common.collect.ImmutableList
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Helper channel "shrinkly/native":
 *  - video info + thumbnail, "move app to background", compression-service checks (for the Compress tab)
 *  - exportShort / exportProgress / cancelExport: the Shorts engine built on Media3 Transformer
 */
@androidx.annotation.OptIn(UnstableApi::class)
class MainActivity : FlutterActivity() {
    private val ui = Handler(Looper.getMainLooper())

    private var transformer: Transformer? = null
    private var pending: MethodChannel.Result? = null
    private var pendingOverlay: Bitmap? = null
    private var tmpOut: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shrinkly/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Back button while busy: keep the app (and its state) alive.
                    "toBack" -> {
                        moveTaskToBack(true)
                        result.success(true)
                    }
                    // Is the compression service (from the plugin) still running?
                    "active" -> result.success(isCompressing())
                    // Size of a finished output file in the Movies folder (null if not there yet).
                    "findOutput" -> {
                        val name = call.argument<String>("name")
                        val since = call.argument<Number>("since")?.toLong() ?: 0L
                        if (name == null) {
                            result.success(null)
                        } else {
                            Thread {
                                val out = findOutput(name, since)
                                ui.post { result.success(out) }
                            }.start()
                        }
                    }
                    "info" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.success(null)
                        } else {
                            Thread {
                                val out = readInfo(path)
                                ui.post { result.success(out) }
                            }.start()
                        }
                    }
                    "thumb" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.success(null)
                        } else {
                            Thread {
                                val out = readThumb(path)
                                ui.post { result.success(out) }
                            }.start()
                        }
                    }
                    "exportShort" -> startExport(call, result)
                    "exportProgress" -> result.success(exportProgress())
                    "cancelExport" -> {
                        transformer?.cancel()
                        cleanupExport()
                        reply(mapOf("status" to "cancelled"))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ------------------------------------------------------------------ Shorts export

    private fun reply(value: Map<String, Any?>) {
        val r = pending
        pending = null
        r?.success(value)
    }

    private fun cleanupExport() {
        transformer = null
        pendingOverlay?.recycle()
        pendingOverlay = null
        tmpOut?.delete()
        tmpOut = null
    }

    private fun exportProgress(): Double {
        val t = transformer ?: return 0.0
        val holder = ProgressHolder()
        val state = t.getProgress(holder)
        return if (state == Transformer.PROGRESS_STATE_AVAILABLE) holder.progress / 100.0 else 0.0
    }

    private fun startExport(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        if (pending != null) {
            result.success(mapOf("status" to "error", "message" to "busy"))
            return
        }
        val path = call.argument<String>("path")
        val outName = call.argument<String>("outName")
        if (path == null || outName == null) {
            result.success(mapOf("status" to "error", "message" to "bad arguments"))
            return
        }
        val startMs = call.argument<Number>("startMs")?.toLong() ?: 0L
        val endMs = call.argument<Number>("endMs")?.toLong() ?: 0L
        val width = call.argument<Number>("width")?.toInt() ?: 720
        val height = call.argument<Number>("height")?.toInt() ?: 1280
        val bitrate = call.argument<Number>("bitrate")?.toInt() ?: 4_000_000
        // Crop window as fractions of the (upright) source picture, 0..1 from the top-left.
        val cropL = call.argument<Number>("cl")?.toFloat() ?: 0f
        val cropT = call.argument<Number>("ct")?.toFloat() ?: 0f
        val cropR = call.argument<Number>("cr")?.toFloat() ?: 1f
        val cropB = call.argument<Number>("cb")?.toFloat() ?: 1f
        val overlayPath = call.argument<String>("overlay")

        pending = result
        try {
            val clip = MediaItem.ClippingConfiguration.Builder()
                .setStartPositionMs(startMs)
                .setEndPositionMs(endMs)
                .build()
            val item = MediaItem.Builder()
                .setUri(Uri.fromFile(File(path)))
                .setClippingConfiguration(clip)
                .build()

            val effects = ArrayList<Effect>()
            // 1) cut out the 9:16 window the user chose (normalised device coordinates: -1..1,
            //    y grows upwards), 2) scale it to the output size (never larger than the source).
            if (cropL > 0.001f || cropT > 0.001f || cropR < 0.999f || cropB < 0.999f) {
                effects.add(
                    androidx.media3.effect.Crop(
                        -1f + 2f * cropL,
                        -1f + 2f * cropR,
                        1f - 2f * cropB,
                        1f - 2f * cropT
                    )
                )
            }
            effects.add(Presentation.createForWidthAndHeight(width, height, Presentation.LAYOUT_SCALE_TO_FIT))
            if (overlayPath != null) {
                val bmp = BitmapFactory.decodeFile(overlayPath)
                if (bmp != null) {
                    pendingOverlay = bmp
                    // The overlay picture has the same size as the output, so it covers the frame 1:1.
                    val overlay = BitmapOverlay.createStaticBitmapOverlay(bmp)
                    effects.add(OverlayEffect(ImmutableList.of<TextureOverlay>(overlay)))
                }
            }

            val edited = EditedMediaItem.Builder(item)
                .setEffects(Effects(ArrayList<AudioProcessor>(), effects))
                .build()

            val encoder = DefaultEncoderFactory.Builder(this)
                .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(bitrate).build())
                .build()

            val out = File(cacheDir, "short_export.mp4")
            if (out.exists()) out.delete()
            tmpOut = out

            val t = Transformer.Builder(this)
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setEncoderFactory(encoder)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        val file = tmpOut
                        Thread {
                            val saved = if (file != null) saveToMovies(file, outName) else null
                            ui.post {
                                cleanupExport()
                                if (saved != null) {
                                    reply(mapOf("status" to "ok", "uri" to saved))
                                } else {
                                    reply(mapOf("status" to "error", "message" to "could not save the file"))
                                }
                            }
                        }.start()
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException
                    ) {
                        cleanupExport()
                        reply(mapOf("status" to "error", "message" to (exportException.message ?: "export failed")))
                    }
                })
                .build()
            transformer = t
            t.start(edited, out.absolutePath)
        } catch (e: Exception) {
            cleanupExport()
            reply(mapOf("status" to "error", "message" to (e.message ?: "export failed")))
        }
    }

    private fun saveToMovies(file: File, displayName: String): String? {
        return try {
            if (Build.VERSION.SDK_INT >= 29) {
                val values = ContentValues().apply {
                    put(MediaStore.Video.Media.DISPLAY_NAME, displayName)
                    put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                    put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/Shrinkly")
                    put(MediaStore.Video.Media.IS_PENDING, 1)
                }
                val uri = contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
                    ?: return null
                contentResolver.openOutputStream(uri)?.use { out ->
                    file.inputStream().use { it.copyTo(out) }
                }
                values.clear()
                values.put(MediaStore.Video.Media.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                uri.toString()
            } else {
                @Suppress("DEPRECATION")
                val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), "Shrinkly")
                dir.mkdirs()
                val dest = File(dir, displayName)
                file.copyTo(dest, true)
                MediaScannerConnection.scanFile(this, arrayOf(dest.absolutePath), arrayOf("video/mp4"), null)
                dest.absolutePath
            }
        } catch (e: Exception) {
            null
        }
    }

    // ------------------------------------------------------------------ Compress tab helpers

    @Suppress("DEPRECATION")
    private fun isCompressing(): Boolean {
        return try {
            val am = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
            am.getRunningServices(100).any { it.service.className.contains("CompressionForegroundService") }
        } catch (e: Exception) {
            false
        }
    }

    private fun findOutput(name: String, sinceMs: Long): Long? {
        return try {
            val proj = arrayOf(MediaStore.Video.Media.SIZE)
            val sel = "${MediaStore.Video.Media.DISPLAY_NAME}=? AND ${MediaStore.Video.Media.DATE_ADDED}>=?"
            val args = arrayOf(name, (sinceMs / 1000L - 5L).toString())
            contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI, proj, sel, args,
                "${MediaStore.Video.Media.DATE_ADDED} DESC"
            )?.use { c -> if (c.moveToFirst()) c.getLong(0) else null }
        } catch (e: Exception) {
            null
        }
    }

    private fun readInfo(path: String): Map<String, Any>? {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            fun num(key: Int): Long = r.extractMetadata(key)?.toLongOrNull() ?: 0L
            val rot = num(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION).toInt()
            var w = num(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH).toInt()
            var h = num(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT).toInt()
            if (rot == 90 || rot == 270) {
                val t = w
                w = h
                h = t
            }
            val fps = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_CAPTURE_FRAMERATE)
                ?.toDoubleOrNull() ?: 0.0
            return mapOf(
                "durationMs" to num(MediaMetadataRetriever.METADATA_KEY_DURATION),
                "width" to w.toLong(),
                "height" to h.toLong(),
                "bitrate" to num(MediaMetadataRetriever.METADATA_KEY_BITRATE),
                "fps" to fps
            )
        } catch (e: Exception) {
            return null
        } finally {
            try {
                r.release()
            } catch (e: Exception) {
            }
        }
    }

    private fun readThumb(path: String): ByteArray? {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            var bmp = r.getFrameAtTime(1_000_000L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
            if (bmp == null) bmp = r.getFrameAtTime(0L)
            if (bmp == null) return null
            val w = 360
            val h = Math.max(1, (bmp.height * w.toFloat() / bmp.width).toInt())
            val scaled = Bitmap.createScaledBitmap(bmp, w, h, true)
            val bos = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 80, bos)
            if (scaled !== bmp) scaled.recycle()
            bmp.recycle()
            return bos.toByteArray()
        } catch (e: Exception) {
            return null
        } finally {
            try {
                r.release()
            } catch (e: Exception) {
            }
        }
    }
}

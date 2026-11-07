package __PKG__

import android.content.ContentValues
import android.content.Intent
import android.provider.OpenableColumns
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
    private var pickResult: MethodChannel.Result? = null
    private val pickCode = 4711

    /** Opens the system video picker and returns the chosen video as a content:// uri (no copying). */
    private fun pickVideo(result: MethodChannel.Result) {
        if (pickResult != null) {
            result.success(null)
            return
        }
        pickResult = result
        try {
            val i = Intent(Intent.ACTION_OPEN_DOCUMENT)
            i.addCategory(Intent.CATEGORY_OPENABLE)
            i.type = "video/*"
            @Suppress("DEPRECATION")
            startActivityForResult(i, pickCode)
        } catch (e: Throwable) {
            pickResult = null
            result.success(null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != pickCode) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val r = pickResult
        pickResult = null
        val uri = if (resultCode == RESULT_OK) data?.data else null
        if (r == null) return
        if (uri == null) {
            r.success(null)
            return
        }
        var name = "video"
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) name = c.getString(0) ?: name
            }
        } catch (e: Exception) {
        }
        r.success(mapOf("uri" to uri.toString(), "name" to name))
    }

    /** Shorts saved by the app (Movies/Shrinkly), newest first. */
    private fun listWorks(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        try {
            val proj = arrayOf(
                MediaStore.Video.Media._ID,
                MediaStore.Video.Media.DISPLAY_NAME,
                MediaStore.Video.Media.SIZE,
                MediaStore.Video.Media.DURATION,
                MediaStore.Video.Media.DATE_ADDED
            )
            val sel: String
            val args: Array<String>
            if (Build.VERSION.SDK_INT >= 29) {
                sel = "${MediaStore.Video.Media.RELATIVE_PATH} LIKE ? AND ${MediaStore.Video.Media.DISPLAY_NAME} LIKE ?"
                args = arrayOf("Movies/Shrinkly%", "Short_%")
            } else {
                @Suppress("DEPRECATION")
                sel = "${MediaStore.Video.Media.DATA} LIKE ? AND ${MediaStore.Video.Media.DISPLAY_NAME} LIKE ?"
                args = arrayOf("%/Movies/Shrinkly/%", "Short_%")
            }
            contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI, proj, sel, args,
                "${MediaStore.Video.Media.DATE_ADDED} DESC"
            )?.use { c ->
                while (c.moveToNext()) {
                    val id = c.getLong(0)
                    val uri = android.content.ContentUris.withAppendedId(
                        MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id
                    )
                    out.add(
                        mapOf(
                            "uri" to uri.toString(),
                            "name" to (c.getString(1) ?: ""),
                            "size" to c.getLong(2),
                            "durationMs" to c.getLong(3),
                            "added" to c.getLong(4)
                        )
                    )
                }
            }
        } catch (e: Exception) {
        }
        return out
    }

    private fun openVideo(uri: String?): Boolean {
        if (uri == null) return false
        return try {
            val i = Intent(Intent.ACTION_VIEW)
            i.setDataAndType(Uri.parse(uri), "video/*")
            i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(i)
            true
        } catch (e: Throwable) {
            false
        }
    }

    private fun shareVideo(uri: String?): Boolean {
        if (uri == null) return false
        return try {
            val i = Intent(Intent.ACTION_SEND)
            i.type = "video/mp4"
            i.putExtra(Intent.EXTRA_STREAM, Uri.parse(uri))
            i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            startActivity(Intent.createChooser(i, null))
            true
        } catch (e: Throwable) {
            false
        }
    }

    private fun deleteWork(uri: String?): Boolean {
        if (uri == null) return false
        return try {
            contentResolver.delete(Uri.parse(uri), null, null) > 0
        } catch (e: Throwable) {
            false
        }
    }

    private fun toUri(path: String): Uri =
        if (path.startsWith("content://")) Uri.parse(path) else Uri.fromFile(File(path))

    private fun MediaMetadataRetriever.setSource(path: String) {
        if (path.startsWith("content://")) setDataSource(this@MainActivity, Uri.parse(path)) else setDataSource(path)
    }

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
                    "pickVideo" -> pickVideo(result)
                    "listWorks" -> Thread {
                        val out = listWorks()
                        ui.post { result.success(out) }
                    }.start()
                    "openVideo" -> result.success(openVideo(call.argument<String>("uri")))
                    "shareVideo" -> result.success(shareVideo(call.argument<String>("uri")))
                    "deleteWork" -> result.success(deleteWork(call.argument<String>("uri")))
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
                .setUri(toUri(path))
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
        } catch (e: Throwable) {
            cleanupExport()
            reply(mapOf("status" to "error", "message" to (e.message ?: e.javaClass.simpleName)))
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
            // The system may rename a clashing file ("x_shrunk (1).mp4"), so match on the base name.
            val base = name.substringBeforeLast('.')
            val sel = "${MediaStore.Video.Media.DISPLAY_NAME} LIKE ? AND ${MediaStore.Video.Media.DATE_ADDED}>=?"
            val args = arrayOf("$base%", (sinceMs / 1000L - 5L).toString())
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
            r.setSource(path)
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
            r.setSource(path)
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

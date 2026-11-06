package __PKG__

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/** Small helper channel: video info (duration, size, bitrate) and a thumbnail. */
class MainActivity : FlutterActivity() {
    private val ui = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shrinkly/native")
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (path == null) {
                    result.notImplemented()
                } else if (call.method == "info") {
                    Thread {
                        val out = readInfo(path)
                        ui.post { result.success(out) }
                    }.start()
                } else if (call.method == "thumb") {
                    Thread {
                        val out = readThumb(path)
                        ui.post { result.success(out) }
                    }.start()
                } else {
                    result.notImplemented()
                }
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

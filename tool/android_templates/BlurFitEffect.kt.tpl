package __PKG__

import android.content.Context
import android.opengl.GLES20
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram
import androidx.media3.effect.SingleFrameGlShaderProgram

/**
 * Draws the video inside a 9:16 frame in one GPU pass:
 *  - the sharp video, scaled by (fgW, fgH) relative to the output (values above 1 crop the
 *    edges; [panX]/[panY] choose which part stays), and
 *  - everywhere the video does not reach, a blurred, darkened copy of the same video that
 *    fills the whole frame (scale bgW, bgH).
 * Pan values are in texture space (y grows upwards).
 */
@androidx.annotation.OptIn(UnstableApi::class)
class BlurFitEffect(
    private val outWidth: Int,
    private val outHeight: Int,
    private val fgW: Float,
    private val fgH: Float,
    private val bgW: Float,
    private val bgH: Float,
    private val panX: Float,
    private val panY: Float
) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram {
        return BlurFitProgram(useHdr, outWidth, outHeight, fgW, fgH, bgW, bgH, panX, panY)
    }
}

@androidx.annotation.OptIn(UnstableApi::class)
private class BlurFitProgram(
    useHdr: Boolean,
    private val outWidth: Int,
    private val outHeight: Int,
    private val fgW: Float,
    private val fgH: Float,
    private val bgW: Float,
    private val bgH: Float,
    private val panX: Float,
    private val panY: Float
) : SingleFrameGlShaderProgram(useHdr) {

    private val program: GlProgram

    init {
        try {
            program = GlProgram(VERTEX, FRAGMENT)
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e)
        }
    }

    override fun configure(inputWidth: Int, inputHeight: Int): Size {
        return Size(outWidth, outHeight)
    }

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        try {
            program.use()
            program.setSamplerTexIdUniform("uTexSampler", inputTexId, 0)
            program.setFloatsUniform("uFg", floatArrayOf(fgW, fgH))
            program.setFloatsUniform("uBg", floatArrayOf(bgW, bgH))
            program.setFloatsUniform("uPan", floatArrayOf(panX, panY))
            program.setBufferAttribute(
                "aFramePosition",
                GlUtil.getNormalizedCoordinateBounds(),
                GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE
            )
            program.bindAttributesAndUniforms()
            GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e, presentationTimeUs)
        }
    }

    override fun release() {
        super.release()
        try {
            program.delete()
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e)
        }
    }

    companion object {
        private const val VERTEX = """
attribute vec4 aFramePosition;
varying vec2 vP;
void main() {
  gl_Position = aFramePosition;
  vP = aFramePosition.xy * 0.5 + 0.5;
}
"""
        private const val FRAGMENT = """
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
uniform sampler2D uTexSampler;
uniform vec2 uFg;
uniform vec2 uBg;
uniform vec2 uPan;
varying vec2 vP;

float mapAxis(float p, float scale, float pan) {
  if (scale >= 1.0) {
    return pan * (1.0 - 1.0 / scale) + p / scale;
  }
  return (p - 0.5) / scale + 0.5;
}

vec3 tap(vec2 t) {
  return texture2D(uTexSampler, clamp(t, 0.0, 1.0)).rgb;
}

void main() {
  vec2 t = vec2(mapAxis(vP.x, uFg.x, uPan.x), mapAxis(vP.y, uFg.y, uPan.y));
  if (t.x >= 0.0 && t.x <= 1.0 && t.y >= 0.0 && t.y <= 1.0) {
    gl_FragColor = vec4(texture2D(uTexSampler, t).rgb, 1.0);
    return;
  }
  vec2 b = (vP - 0.5) / uBg + 0.5;
  vec3 acc = tap(b);
  float total = 1.0;
  for (int i = 0; i < 12; i++) {
    float a = float(i) * 0.5235988;
    vec2 d = vec2(cos(a), sin(a));
    acc += tap(b + d * 0.035);
    acc += tap(b + d * 0.018);
    total += 2.0;
  }
  gl_FragColor = vec4((acc / total) * 0.72, 1.0);
}
"""
    }
}

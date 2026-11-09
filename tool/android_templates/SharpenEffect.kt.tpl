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
 * Mild "unsharp mask" sharpening applied on the GPU to every video frame:
 * result = pixel + (pixel - average of its 4 neighbours) * amount.
 */
@androidx.annotation.OptIn(UnstableApi::class)
class SharpenEffect(private val amount: Float) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram {
        return SharpenProgram(useHdr, amount)
    }
}

@androidx.annotation.OptIn(UnstableApi::class)
private class SharpenProgram(useHdr: Boolean, private val amount: Float) : SingleFrameGlShaderProgram(useHdr) {

    private val program: GlProgram
    private var width = 1
    private var height = 1

    init {
        try {
            program = GlProgram(VERTEX, FRAGMENT)
        } catch (e: GlUtil.GlException) {
            throw VideoFrameProcessingException(e)
        }
    }

    override fun configure(inputWidth: Int, inputHeight: Int): Size {
        width = inputWidth
        height = inputHeight
        return Size(inputWidth, inputHeight)
    }

    override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
        try {
            program.use()
            program.setSamplerTexIdUniform("uTexSampler", inputTexId, false)
            program.setFloatsUniform("uTexel", floatArrayOf(1f / width, 1f / height))
            program.setFloatUniform("uAmount", amount)
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
varying vec2 vTexSamplingCoord;
void main() {
  gl_Position = aFramePosition;
  vTexSamplingCoord = aFramePosition.xy * 0.5 + 0.5;
}
"""
        private const val FRAGMENT = """
precision mediump float;
uniform sampler2D uTexSampler;
uniform vec2 uTexel;
uniform float uAmount;
varying vec2 vTexSamplingCoord;
void main() {
  vec4 c = texture2D(uTexSampler, vTexSamplingCoord);
  vec4 n = texture2D(uTexSampler, vTexSamplingCoord + vec2(0.0, uTexel.y));
  vec4 s = texture2D(uTexSampler, vTexSamplingCoord - vec2(0.0, uTexel.y));
  vec4 e = texture2D(uTexSampler, vTexSamplingCoord + vec2(uTexel.x, 0.0));
  vec4 w = texture2D(uTexSampler, vTexSamplingCoord - vec2(uTexel.x, 0.0));
  vec3 blur = (n.rgb + s.rgb + e.rgb + w.rgb) * 0.25;
  gl_FragColor = vec4(clamp(c.rgb + (c.rgb - blur) * uAmount, 0.0, 1.0), c.a);
}
"""
    }
}

package com.aderiktech.safefamily

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.aderiktech.safefamily/emergency_alarm"
    private val handler = Handler(Looper.getMainLooper())
    private var tone: ToneGenerator? = null
    private var sirenRunning = false
    private var torchRunning = false
    private var torchOn = false
    private var cameraId: String? = null
    private var pendingResult: MethodChannel.Result? = null

    private val sirenTask = object : Runnable {
        override fun run() {
            if (!sirenRunning) return
            try {
                if (tone == null) tone = ToneGenerator(AudioManager.STREAM_ALARM, 100)
                tone?.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 850)
                handler.postDelayed(this, 950)
            } catch (_: Exception) {
                stopSiren()
            }
        }
    }

    private val torchTask = object : Runnable {
        override fun run() {
            if (!torchRunning) return
            setTorch(!torchOn)
            if (torchRunning) handler.postDelayed(this, 350)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSiren" -> {
                        startSiren()
                        result.success(null)
                    }
                    "stopSiren" -> {
                        stopSiren()
                        result.success(null)
                    }
                    "startTorch" -> startTorch(result)
                    "stopTorch" -> {
                        stopTorch()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startSiren() {
        if (sirenRunning) return
        sirenRunning = true
        handler.removeCallbacks(sirenTask)
        sirenTask.run()
    }

    private fun stopSiren() {
        sirenRunning = false
        handler.removeCallbacks(sirenTask)
        try {
            tone?.stopTone()
            tone?.release()
        } catch (_: Exception) {
        }
        tone = null
    }

    private fun startTorch(result: MethodChannel.Result) {
        if (torchRunning) {
            result.success(null)
            return
        }
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            pendingResult = result
            requestPermissions(arrayOf(Manifest.permission.CAMERA), CAMERA_REQUEST)
            return
        }
        beginTorch(result)
    }

    private fun beginTorch(result: MethodChannel.Result) {
        try {
            val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val id = manager.cameraIdList.firstOrNull {
                manager.getCameraCharacteristics(it).get(
                    android.hardware.camera2.CameraCharacteristics.FLASH_INFO_AVAILABLE
                ) == true
            }
            if (id == null) {
                result.error("no_torch", "No flashlight is available on this device.", null)
                return
            }
            cameraId = id
            torchRunning = true
            torchOn = false
            handler.removeCallbacks(torchTask)
            torchTask.run()
            result.success(null)
        } catch (e: Exception) {
            torchRunning = false
            result.error("torch_failed", e.message ?: "Could not start flashlight.", null)
        }
    }

    private fun setTorch(enabled: Boolean) {
        val id = cameraId ?: return
        try {
            val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            manager.setTorchMode(id, enabled)
            torchOn = enabled
        } catch (_: Exception) {
            torchRunning = false
            handler.removeCallbacks(torchTask)
        }
    }

    private fun stopTorch() {
        torchRunning = false
        handler.removeCallbacks(torchTask)
        val id = cameraId
        if (id != null) {
            try {
                val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
                manager.setTorchMode(id, false)
            } catch (_: Exception) {
            }
        }
        torchOn = false
        cameraId = null
    }

    @Deprecated("Deprecated in Android")
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CAMERA_REQUEST) return
        val result = pendingResult
        pendingResult = null
        if (result == null) return
        if (grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            beginTorch(result)
        } else {
            result.error("permission_denied", "Camera permission is needed for the flashlight.", null)
        }
    }

    override fun onDestroy() {
        stopSiren()
        stopTorch()
        pendingResult = null
        super.onDestroy()
    }

    companion object {
        private const val CAMERA_REQUEST = 4107
    }
}

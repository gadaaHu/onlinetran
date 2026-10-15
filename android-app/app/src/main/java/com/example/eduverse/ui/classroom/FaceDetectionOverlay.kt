package com.example.eduverse.ui.classroom

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.View
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import java.util.concurrent.Executors

// ─────────────────────────────────────────────────────────────────────────────
// Custom overlay View – draws high-precision face bounding boxes
// ─────────────────────────────────────────────────────────────────────────────
class FaceBoundingBoxOverlay @JvmOverloads constructor(
    context: Context, attrs: AttributeSet? = null
) : View(context, attrs) {

    // Corner bracket stroke paint – Emerald Green
    private val cornerPaint = Paint().apply {
        color = android.graphics.Color.parseColor("#10B981")
        style = Paint.Style.STROKE
        strokeWidth = 7f
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
        isAntiAlias = true
    }
    // Subtle inner glow fill
    private val fillPaint = Paint().apply {
        color = android.graphics.Color.parseColor("#1510B981")
        style = Paint.Style.FILL
        isAntiAlias = true
    }
    // Scan-line effect across the face
    private val scanPaint = Paint().apply {
        color = android.graphics.Color.parseColor("#4010B981")
        style = Paint.Style.STROKE
        strokeWidth = 2f
        isAntiAlias = true
    }
    // Badge background
    private val badgeBgPaint = Paint().apply {
        color = android.graphics.Color.parseColor("#DD065F46")
        style = Paint.Style.FILL
        isAntiAlias = true
    }
    private val textPaint = Paint().apply {
        color = android.graphics.Color.WHITE
        textSize = 26f
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        isAntiAlias = true
    }
    private val subTextPaint = Paint().apply {
        color = android.graphics.Color.parseColor("#A7F3D0")
        textSize = 20f
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        isAntiAlias = true
    }

    var faces: List<Face> = emptyList()
        set(value) { field = value; postInvalidate() }

    var imageWidth: Int = 0
    var imageHeight: Int = 0
    var isFrontCamera: Boolean = true

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (faces.isEmpty() || imageWidth == 0 || imageHeight == 0) return

        val scaleX = width.toFloat() / imageWidth.toFloat()
        val scaleY = height.toFloat() / imageHeight.toFloat()
        val scale = maxOf(scaleX, scaleY)
        val offsetX = (width - imageWidth * scale) / 2f
        val offsetY = (height - imageHeight * scale) / 2f

        for ((index, face) in faces.withIndex()) {
            val bounds = face.boundingBox

            val left: Float
            val right: Float
            if (isFrontCamera) {
                left = (imageWidth - bounds.right) * scale + offsetX
                right = (imageWidth - bounds.left) * scale + offsetX
            } else {
                left = bounds.left * scale + offsetX
                right = bounds.right * scale + offsetX
            }
            val top = bounds.top * scale + offsetY
            val bottom = bounds.bottom * scale + offsetY
            val w = right - left
            val h = bottom - top

            val rect = RectF(left, top, right, bottom)

            // 1. Soft inner fill
            canvas.drawRoundRect(rect, 12f, 12f, fillPaint)

            // 2. Horizontal scan line (midpoint)
            val midY = top + h / 2f
            canvas.drawLine(left + 12f, midY, right - 12f, midY, scanPaint)

            // 3. Corner brackets – length is 22% of the smaller dimension
            val arm = minOf(w, h) * 0.22f
            val r = 14f
            // Top-left
            canvas.drawLine(left, top + arm, left, top + r, cornerPaint)
            canvas.drawLine(left + r, top, left + arm, top, cornerPaint)
            canvas.drawArc(RectF(left, top, left + r * 2, top + r * 2), 180f, 90f, false, cornerPaint)
            // Top-right
            canvas.drawLine(right - arm, top, right - r, top, cornerPaint)
            canvas.drawLine(right, top + r, right, top + arm, cornerPaint)
            canvas.drawArc(RectF(right - r * 2, top, right, top + r * 2), 270f, 90f, false, cornerPaint)
            // Bottom-left
            canvas.drawLine(left, bottom - arm, left, bottom - r, cornerPaint)
            canvas.drawLine(left + r, bottom, left + arm, bottom, cornerPaint)
            canvas.drawArc(RectF(left, bottom - r * 2, left + r * 2, bottom), 90f, 90f, false, cornerPaint)
            // Bottom-right
            canvas.drawLine(right - arm, bottom, right - r, bottom, cornerPaint)
            canvas.drawLine(right, bottom - r, right, bottom - arm, cornerPaint)
            canvas.drawArc(RectF(right - r * 2, bottom - r * 2, right, bottom), 0f, 90f, false, cornerPaint)

            // 4. Badge below the face frame
            val label = "✓ Face ${index + 1} Verified"
            val sub = "Attendance Recorded"
            val labelW = maxOf(textPaint.measureText(label), subTextPaint.measureText(sub)) + 28f
            val labelH = 54f
            val badgeLeft = left
            val badgeTop = minOf(bottom + 8f, height - labelH - 4f)
            val badgeRect = RectF(badgeLeft, badgeTop, badgeLeft + labelW, badgeTop + labelH)
            canvas.drawRoundRect(badgeRect, 10f, 10f, badgeBgPaint)
            canvas.drawText(label, badgeLeft + 14f, badgeTop + 22f, textPaint)
            canvas.drawText(sub, badgeLeft + 14f, badgeTop + 46f, subTextPaint)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Composable: CameraX Preview + ML Kit Face Detection with Fullscreen Support
// ─────────────────────────────────────────────────────────────────────────────
@SuppressLint("MissingPermission")
@Composable
fun FaceDetectionCameraView(
    isInstructor: Boolean,
    onFaceCountChanged: (Int) -> Unit,
    modifier: Modifier = Modifier,
    isFullscreen: Boolean = false,
    onToggleFullscreen: (() -> Unit)? = null
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var faceCount by remember { mutableIntStateOf(0) }
    var noFaceWarning by remember { mutableStateOf(false) }

    // Front camera is always allowed and defaults to FRONT so student/instructor face is detected
    var isFrontCamera by remember { mutableStateOf(true) }

    val previewView = remember {
        PreviewView(context).apply {
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            scaleType = PreviewView.ScaleType.FILL_CENTER
            layoutParams = android.widget.FrameLayout.LayoutParams(
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
    }

    val overlay = remember {
        FaceBoundingBoxOverlay(context).apply {
            layoutParams = android.widget.FrameLayout.LayoutParams(
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
                android.widget.FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
    }

    LaunchedEffect(faceCount) {
        onFaceCountChanged(faceCount)
        noFaceWarning = faceCount == 0
    }

    // Bind and dynamically rebind camera whenever isFrontCamera is toggled
    DisposableEffect(isFrontCamera, lifecycleOwner) {
        overlay.isFrontCamera = isFrontCamera
        val cameraExecutor = Executors.newSingleThreadExecutor()

        val detectorOptions = FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_NONE)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_NONE)
            .setMinFaceSize(0.15f)
            .enableTracking()
            .build()
        val detector = FaceDetection.getClient(detectorOptions)

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()
                cameraProvider.unbindAll()

                val preview = Preview.Builder().build().also {
                    it.surfaceProvider = previewView.surfaceProvider
                }

                val targetFacing = if (isFrontCamera) CameraSelector.LENS_FACING_FRONT
                                   else CameraSelector.LENS_FACING_BACK

                val cameraSelector = CameraSelector.Builder()
                    .requireLensFacing(targetFacing)
                    .build()

                val imageAnalysis = ImageAnalysis.Builder()
                    .setResolutionSelector(
                        androidx.camera.core.resolutionselector.ResolutionSelector.Builder()
                            .setResolutionStrategy(
                                androidx.camera.core.resolutionselector.ResolutionStrategy(
                                    android.util.Size(640, 480),
                                    androidx.camera.core.resolutionselector.ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER
                                )
                            ).build()
                    )
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()

                imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                    processImageProxy(imageProxy, detector, overlay) { count ->
                        faceCount = count
                    }
                }

                cameraProvider.bindToLifecycle(
                    lifecycleOwner, cameraSelector, preview, imageAnalysis
                )
            } catch (e: Exception) {
                try {
                    val cameraProvider = cameraProviderFuture.get()
                    cameraProvider.unbindAll()
                    val preview = Preview.Builder().build().also {
                        it.surfaceProvider = previewView.surfaceProvider
                    }
                    val fallbackSelector = CameraSelector.DEFAULT_BACK_CAMERA
                    cameraProvider.bindToLifecycle(lifecycleOwner, fallbackSelector, preview)
                } catch (_: Exception) {}
            }
        }, ContextCompat.getMainExecutor(context))

        onDispose {
            try {
                val cameraProvider = cameraProviderFuture.get()
                cameraProvider.unbindAll()
                cameraExecutor.shutdown()
            } catch (_: Exception) {}
        }
    }

    Box(modifier = modifier) {
        AndroidView(
            factory = {
                android.widget.FrameLayout(context).apply {
                    addView(previewView)
                    addView(overlay)
                }
            },
            modifier = Modifier.fillMaxSize()
        )

        // Status banner
        Column(
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            // Face count badge
            Row(
                modifier = Modifier
                    .background(
                        color = if (faceCount > 0) Color(0xCC10B981) else Color(0xCCEF4444),
                        shape = RoundedCornerShape(20.dp)
                    )
                    .padding(horizontal = 10.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Text(
                    text = if (faceCount > 0) "👤" else "❌",
                    fontSize = 12.sp
                )
                Text(
                    text = if (faceCount > 0) "$faceCount face${if (faceCount > 1) "s" else ""} detected"
                    else "No face detected",
                    color = Color.White,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }

            // Camera toggle, Fullscreen & Role tags
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Interactive Front / Back Camera Switch Button
                Surface(
                    color = Color(0xDD2563EB),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.clickable { isFrontCamera = !isFrontCamera }
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text(
                            text = if (isFrontCamera) "🤳 Front Cam" else "📷 Back Cam",
                            color = Color.White,
                            fontSize = 10.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text("🔄", fontSize = 10.sp)
                    }
                }

                if (onToggleFullscreen != null) {
                    Surface(
                        color = Color(0xDD4B5563),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.clickable { onToggleFullscreen() }
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Text(
                                text = if (isFullscreen) "↙ Split View" else "⛶ Full Camera",
                                color = Color.White,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }

                Text(
                    text = if (isInstructor) "🎓 Instructor" else "🎓 Student",
                    modifier = Modifier
                        .background(Color(0x99000000), RoundedCornerShape(8.dp))
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    color = Color.White,
                    fontSize = 10.sp
                )
            }
        }

        // Warning overlay when no face visible
        AnimatedVisibility(
            visible = noFaceWarning,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color(0xCCEF4444))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "⚠️ Face not visible — please look into the front camera",
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@SuppressLint("UnsafeOptInUsageError")
private fun processImageProxy(
    imageProxy: ImageProxy,
    detector: com.google.mlkit.vision.face.FaceDetector,
    overlay: FaceBoundingBoxOverlay,
    onFaceCount: (Int) -> Unit
) {
    val mediaImage = imageProxy.image ?: run { imageProxy.close(); return }
    val rotation = imageProxy.imageInfo.rotationDegrees
    val inputImage = InputImage.fromMediaImage(mediaImage, rotation)

    val isRotated = rotation == 90 || rotation == 270
    overlay.imageWidth = if (isRotated) imageProxy.height else imageProxy.width
    overlay.imageHeight = if (isRotated) imageProxy.width else imageProxy.height

    detector.process(inputImage)
        .addOnSuccessListener { faces ->
            overlay.faces = faces
            onFaceCount(faces.size)
        }
        .addOnFailureListener { /* silent */ }
        .addOnCompleteListener {
            imageProxy.close()
        }
}

package com.reactnativemlkitocr

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Point
import android.graphics.Rect
import android.net.Uri
import android.util.Base64
import com.facebook.react.bridge.*
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
import java.io.ByteArrayOutputStream
import java.lang.Exception
import java.net.URL


class MlkitOcrModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {
    override fun getName(): String {
        return "MlkitOcr"
    }

    @ReactMethod
    fun detectFromUri(uri: String, promise: Promise) {
        return this.detectFromResource(uri, promise);
    }

    @ReactMethod
    fun detectFromFile(path: String, promise: Promise) {
        return this.detectFromResource(path, promise);
    }

    private fun detectFromResource(path: String, promise: Promise) {
        val image: InputImage;
        try {
            if (path.startsWith("https://") || path.startsWith("http://")) {
                val url = URL(path)
                val connection = url.openConnection()
                connection.connect()
                val inputStream = connection.getInputStream()
                val byteArrayOutputStream = ByteArrayOutputStream()
                inputStream.copyTo(byteArrayOutputStream)
                inputStream.close()
                val bitmap = BitmapFactory.decodeByteArray(
                    byteArrayOutputStream.toByteArray(), 0, byteArrayOutputStream.size()
                )
                image = InputImage.fromBitmap(bitmap, 0)
                inputStream.close()
            } else {
                image = InputImage.fromFilePath(reactApplicationContext, Uri.parse(path))
            }
            val recognizer =
                TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build())
            recognizer.process(image).addOnSuccessListener { visionText ->
                promise.resolve(getDataAsArray(visionText, image))
            }.addOnFailureListener { e ->
                promise.reject(e);
                e.printStackTrace();
            }
        } catch (e: Exception) {
            promise.reject(e);
            e.printStackTrace();
        }
    }

    private fun getCoordinates(boundingBox: Rect?): WritableMap {
        val coordinates: WritableMap = Arguments.createMap()
        if (boundingBox == null) {
            coordinates.putNull("top")
            coordinates.putNull("left")
            coordinates.putNull("width")
            coordinates.putNull("height")
        } else {
            coordinates.putInt("top", boundingBox.top)
            coordinates.putInt("left", boundingBox.left)
            coordinates.putInt("width", boundingBox.width())
            coordinates.putInt("height", boundingBox.height())
        }
        return coordinates;
    }

    private fun getCornerPoints(pointsList: Array<Point>?): WritableArray {
        val p: WritableArray = Arguments.createArray()
        if (pointsList == null) {
            return p;
        }

        pointsList.forEach { point ->
            val i: WritableMap = Arguments.createMap()
            i.putInt("x", point.x);
            i.putInt("y", point.y);
            p.pushMap(i);
        }

        return p;
    }


    private fun getDataAsArray(visionText: Text, image: InputImage): WritableMap? {
        val data: WritableArray = Arguments.createArray()

        for (block in visionText.textBlocks) {
            val blockElements: WritableArray = Arguments.createArray()
            for (line in block.lines) {
                val lineElements: WritableArray = Arguments.createArray()
                for (element in line.elements) {
                    val e: WritableMap = Arguments.createMap()
                    e.putString("text", element.text)
                    e.putMap("bounding", getCoordinates(element.boundingBox))
                    e.putArray("cornerPoints", getCornerPoints(element.cornerPoints))
                    e.putString("confidence", element.confidence.toString())
                    lineElements.pushMap(e)
                }
                val l: WritableMap = Arguments.createMap()
                val lCoordinates = getCoordinates(line.boundingBox)
                l.putString("text", line.text)
                l.putMap("bounding", lCoordinates)
                l.putArray("elements", lineElements)
                l.putArray("cornerPoints", getCornerPoints(line.cornerPoints))
                l.putString("confidence", line.confidence.toString())

                blockElements.pushMap(l)
            }

            val info: WritableMap = Arguments.createMap()


            info.putMap("bounding", getCoordinates(block.boundingBox))
            info.putString("text", block.text)
            info.putArray("lines", blockElements)
            info.putArray("cornerPoints", getCornerPoints(block.cornerPoints))
            data.pushMap(info)
        }

        val res: WritableMap = Arguments.createMap()
        res.putArray("textRecognition", data)
        res.putString("base64Image", image.toBase64())

        return res
    }

    private fun InputImage.toBase64(): String? {
        // 尝试从 InputImage 获取 Bitmap
        val bitmap = when (this) {
            is InputImage -> this.bitmapInternal
            else -> return null // 或者处理其他类型的 InputImage
        } ?: return null

        // 将 Bitmap 转换为字节数组
        val byteArrayOutputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream)
        val imageBytes: ByteArray = byteArrayOutputStream.toByteArray()

        // 对字节数组进行 Base64 编码
        return Base64.encodeToString(imageBytes, Base64.DEFAULT)
    }
}

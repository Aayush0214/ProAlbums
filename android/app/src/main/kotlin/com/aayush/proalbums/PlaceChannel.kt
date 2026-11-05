package com.aayush.proalbums

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.ContentUris
import android.content.pm.PackageManager
import android.location.Address
import android.location.Geocoder
import android.media.ExifInterface
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Callable
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Intelligent classification > Location: where each picture was taken.
 * Dart keeps the answers (each picture is read once, each place named once).
 *  - permission: ACCESS_MEDIA_LOCATION (Android hides a picture's GPS from
 *    apps without it); asks once when not given.
 *  - listImages: every picture (not in the trash): id, modified, taken.
 *  - locations {ids}: id → [lat, lng] for pictures that have a GPS place
 *    (read from the original file's EXIF; nothing for the others).
 *  - placeName {lat, lng}: Android's Geocoder (needs the internet; the
 *    phone's own service, Google on most phones): locality, sub-admin area
 *    (district), admin area (state), country; null when it cannot answer.
 */
class PlaceChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    private val worker = Executors.newSingleThreadExecutor()
    private val pool = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())
    private var pendingPermission: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permission" -> permission(result)
            "listImages" -> background(result) { listImages() }
            "locations" -> {
                val ids = call.argument<List<String>>("ids").orEmpty()
                    .mapNotNull { it.toLongOrNull() }
                background(result) { locations(ids) }
            }
            "placeName" -> {
                val lat = call.argument<Double>("lat") ?: 0.0
                val lng = call.argument<Double>("lng") ?: 0.0
                background(result) { placeName(lat, lng) }
            }
            else -> result.notImplemented()
        }
    }

    private fun granted() = activity.checkSelfPermission(Manifest.permission.ACCESS_MEDIA_LOCATION) ==
        PackageManager.PERMISSION_GRANTED

    private fun permission(result: MethodChannel.Result) {
        if (granted()) {
            result.success(true)
            return
        }
        if (pendingPermission != null) {
            result.success(false)
            return
        }
        pendingPermission = result
        activity.requestPermissions(arrayOf(Manifest.permission.ACCESS_MEDIA_LOCATION), REQUEST_PERMISSION)
    }

    /** Routed from MainActivity; true when it was ours. */
    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_PERMISSION) return false
        pendingPermission?.success(granted())
        pendingPermission = null
        return true
    }

    private fun listImages(): List<Map<String, Any>> {
        val rows = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DATE_MODIFIED,
            MediaStore.MediaColumns.DATE_TAKEN,
            MediaStore.MediaColumns.DATE_ADDED,
        )
        val args = Bundle().apply {
            putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_EXCLUDE)
            putString(ContentResolver.QUERY_ARG_SQL_SORT_ORDER, "${MediaStore.MediaColumns.DATE_TAKEN} DESC")
        }
        activity.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI, projection, args, null,
        )?.use { c ->
            while (c.moveToNext()) {
                val added = c.getLong(3) * 1000
                rows.add(
                    mapOf(
                        "id" to c.getLong(0).toString(),
                        "modified" to c.getLong(1),
                        "taken" to if (c.isNull(2)) added else c.getLong(2),
                    ),
                )
            }
        }
        return rows
    }

    private fun locations(ids: List<Long>): Map<String, List<Double>> {
        if (!granted()) return emptyMap()
        val jobs = ids.map { id ->
            id to pool.submit(Callable {
                try {
                    val uri = MediaStore.setRequireOriginal(
                        ContentUris.withAppendedId(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id),
                    )
                    activity.contentResolver.openInputStream(uri)?.use { input ->
                        val latLng = FloatArray(2)
                        if (ExifInterface(input).getLatLong(latLng) &&
                            PlaceMath.isReal(latLng[0].toDouble(), latLng[1].toDouble())
                        ) {
                            listOf(latLng[0].toDouble(), latLng[1].toDouble())
                        } else {
                            null
                        }
                    }
                } catch (error: Exception) {
                    null
                }
            })
        }
        val out = mutableMapOf<String, List<Double>>()
        for ((id, job) in jobs) job.get()?.let { out[id.toString()] = it }
        return out
    }

    private fun placeName(lat: Double, lng: Double): Map<String, String?>? {
        if (!Geocoder.isPresent()) return null
        val geocoder = Geocoder(activity, Locale.getDefault())
        val address: Address? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val latch = CountDownLatch(1)
            var found: Address? = null
            geocoder.getFromLocation(
                lat, lng, 1,
                object : Geocoder.GeocodeListener {
                    override fun onGeocode(addresses: MutableList<Address>) {
                        found = addresses.firstOrNull()
                        latch.countDown()
                    }

                    override fun onError(errorMessage: String?) {
                        latch.countDown()
                    }
                },
            )
            latch.await(15, TimeUnit.SECONDS)
            found
        } else {
            @Suppress("DEPRECATION")
            geocoder.getFromLocation(lat, lng, 1)?.firstOrNull()
        }
        address ?: return null
        return mapOf(
            "locality" to address.locality,
            "subLocality" to address.subLocality,
            "subAdminArea" to address.subAdminArea,
            "adminArea" to address.adminArea,
            "country" to address.countryName,
        )
    }

    private fun <T> background(result: MethodChannel.Result, work: () -> T) {
        worker.execute {
            val answer = try {
                work()
            } catch (error: Throwable) {
                null
            }
            main.post { result.success(answer) }
        }
    }

    internal companion object {
        const val CHANNEL = "com.aayush.proalbums/places"
        const val REQUEST_PERMISSION = 7207
    }
}

/** Pure maths (JVM-tested). */
internal object PlaceMath {
    /** Not "no GPS" written as 0,0, and inside the world. */
    fun isReal(lat: Double, lng: Double): Boolean =
        !(lat == 0.0 && lng == 0.0) && lat in -90.0..90.0 && lng in -180.0..180.0
}

package yukams.app.background_locator_2.provider

import android.annotation.SuppressLint
import android.content.Context
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import androidx.core.content.ContextCompat
import android.os.Bundle

class AndroidLocationProviderClient(context: Context, override var listener: LocationUpdateListener?) : BLLocationProvider, LocationListener {
    private val client: LocationManager? =
            ContextCompat.getSystemService(context, LocationManager::class.java)

    private var lastFixNanos: Long? = null
    private var minimumIntervalNanos = 0L

    @SuppressLint("MissingPermission")
    override fun removeLocationUpdates() {
        client?.removeUpdates(this)
    }

    @SuppressLint("MissingPermission")
    override fun requestLocationUpdates(request: LocationRequestOptions) {
        minimumIntervalNanos = request.interval * 1_000_000L
        val manager = client ?: return
        for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
            if (manager.isProviderEnabled(provider)) {
                manager.requestLocationUpdates(provider, request.interval, request.distanceFilter, this)
            }
        }
    }

    override fun onLocationChanged(location: Location) {
        // Both providers may report the same moment. Compare monotonic capture times.
        val previous = lastFixNanos
        if (previous != null && location.elapsedRealtimeNanos - previous < minimumIntervalNanos) return
        lastFixNanos = location.elapsedRealtimeNanos
        listener?.onLocationUpdated(LocationParserUtil.getLocationMapFromLocation(location))
    }

    override fun onProviderDisabled(provider: String) {
        // nop
    }

    override fun onProviderEnabled(provider: String) {
        // nop
    }
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

}
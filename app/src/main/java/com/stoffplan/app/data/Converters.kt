package com.stoffplan.app.data

import androidx.room.TypeConverter

class Converters {
    @TypeConverter fun routeToString(r: Route): String = r.name
    @TypeConverter fun stringToRoute(s: String): Route = runCatching { Route.valueOf(s) }.getOrDefault(Route.OTHER)
}

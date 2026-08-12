# Garmin Connect IQ Mobile SDK: seine Parcelable-Klassen (IQDevice, IQApp, ...)
# wandern per Binder/Broadcast zwischen Prozessen -- zwischen dieser App und der
# separat installierten Garmin-Connect-Mobile-App. Der Empfaenger-Prozess loest
# eine Parcelable-CREATOR ueber den vom Sender eingebetteten, unveraenderten
# Klassennamen auf; ohne Keep-Regel benennt R8 diese Klassen im Release-Build um
# (z.B. IQDevice -> l0.i), wodurch Class.forName() im Empfaenger fehlschlaegt --
# Crash mit BadParcelableException/ClassNotFoundException beim ersten
# DEVICE_STATUS-Broadcast (release-only, da Minifizierung im Debug-Build aus ist).
-keep class com.garmin.android.connectiq.** { *; }

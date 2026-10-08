# Razorpay Checkout SDK - required by Razorpay's own integration docs.
# Without these, R8 strips/renames classes the SDK looks up via
# reflection at runtime, breaking checkout with obscure crashes that
# only appear in a minified release build, not debug.
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-optimizations !method/removal/parameter
-keepattributes JavascriptInterface
-keepattributes Signature
-keepattributes *Annotation*

# Google Play Core - Flutter's deferred-components support references
# these classes even when the app doesn't use deferred components. Avoids
# R8 failing the build with "missing class" errors for split-install APIs.
-dontwarn com.google.android.play.core.**

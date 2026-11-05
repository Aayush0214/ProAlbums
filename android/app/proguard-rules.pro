# ONNX Runtime (People face recognition): its native library looks up these
# Java classes by name, so R8 must not rename or remove them.
-keep class ai.onnxruntime.** { *; }

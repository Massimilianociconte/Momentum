# RallyMate does not use reflection for its score/event wire model. Dependency
# consumer rules cover Compose, Play Services and Health Services. Preserve
# runtime annotations used by Android framework integrations while allowing R8
# to optimize the rest of the wearable binary.
-keepattributes RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations,AnnotationDefault

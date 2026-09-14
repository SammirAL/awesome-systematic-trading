{{flutter_js}}
{{flutter_build_config}}

// Serve the CanvasKit engine from this build instead of Google's CDN, so the
// app is fully self-contained and works offline / behind restricted networks.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});

export let KWin = null;
export let Workspace = null;
export let QML = {};
export let config = {};

export function init(kwin, workspace) {
  console.log("KZones: Loading APIs...");
  KWin = kwin || null;
  Workspace = workspace || null;
}

export function registerQMLComponent(name, component) {
  console.log("KZones: Registering QML component:", name);
  try {
    QML[name] = component;
  } catch (error) {
    console.error("KZones: Error registering QML component:", error);
  }
}

export function loadConfig() {
  console.log("KZones: Loading config...");

  const defaultLayouts = [
    {
      name: "Priority Grid",
      padding: 0,
      zones: [
        { x: 0, y: 0, height: 100, width: 25 },
        { x: 25, y: 0, height: 100, width: 50 },
        { x: 75, y: 0, height: 100, width: 25 },
      ],
    },
    {
      name: "Quadrant Grid",
      zones: [
        { x: 0, y: 0, height: 50, width: 50 },
        { x: 0, y: 50, height: 50, width: 50 },
        { x: 50, y: 50, height: 50, width: 50 },
        { x: 50, y: 0, height: 50, width: 50 },
      ],
    },
  ];

  let layouts;
  try {
    layouts = JSON.parse(KWin.readConfig("layoutsJson", JSON.stringify(defaultLayouts)));
  } catch (e) {
    // TODO: Notify user about invalid config and using defaults instead
    layouts = defaultLayouts;
  }

  config.enableZoneSelector = KWin.readConfig("enableZoneSelector", true);
  config.zoneSelectorTriggerDistance = KWin.readConfig("zoneSelectorTriggerDistance", 1);
  config.enableZoneOverlay = KWin.readConfig("enableZoneOverlay", true);
  config.zoneOverlayShowWhen = KWin.readConfig("zoneOverlayShowWhen", 0);
  config.zoneOverlayHighlightTarget = KWin.readConfig("zoneOverlayHighlightTarget", 0);
  config.zoneOverlayIndicatorDisplay = KWin.readConfig("zoneOverlayIndicatorDisplay", 0);
  config.enableEdgeSnapping = KWin.readConfig("enableEdgeSnapping", false);
  config.edgeSnappingTriggerDistance = KWin.readConfig("edgeSnappingTriggerDistance", 1);
  config.requireToolboxShortcut = KWin.readConfig("requireToolboxShortcut", false);
  config.defaultDragMode = KWin.readConfig("defaultDragMode", 0);
  config.toolboxModeOnMoveStart = KWin.readConfig("toolboxModeOnMoveStart", 0);
  config.rememberWindowGeometries = KWin.readConfig("rememberWindowGeometries", true);
  config.trackLayoutPerScreen = KWin.readConfig("trackLayoutPerScreen", false);
  config.trackLayoutPerDesktop = KWin.readConfig("trackLayoutPerDesktop", false);
  config.showOsdMessages = KWin.readConfig("showOsdMessages", true);
  config.fadeWindowsWhileMoving = KWin.readConfig("fadeWindowsWhileMoving", false);
  config.autoSnapAllNew = KWin.readConfig("autoSnapAllNew", false);
  config.enableWindowSnapGuides = KWin.readConfig("enableWindowSnapGuides", false);
  config.windowSnapActivation = KWin.readConfig("windowSnapActivation", 1);
  config.windowSnapActivationCorner = KWin.readConfig("windowSnapActivationCorner", 0);
  config.windowSnapCornerSize = KWin.readConfig("windowSnapCornerSize", 20);
  config.windowSnapDistance = KWin.readConfig("windowSnapDistance", 0);
  config.windowSnapEffect = KWin.readConfig("windowSnapEffect", 0);
  config.windowSnapColor = KWin.readConfig("windowSnapColor", "#3daee9");
  config.windowSnapBorderWidth = KWin.readConfig("windowSnapBorderWidth", 4);
  config.windowSnapGlowEnabled = KWin.readConfig("windowSnapGlowEnabled", true);
  config.windowSnapGlowColor = KWin.readConfig("windowSnapGlowColor", "#3daee9");
  config.windowSnapGlowSize = KWin.readConfig("windowSnapGlowSize", 24);
  config.windowSnapShadowEnabled = KWin.readConfig("windowSnapShadowEnabled", true);
  config.windowSnapShadowColor = KWin.readConfig("windowSnapShadowColor", "#b0000000");
  config.windowSnapShadowSize = KWin.readConfig("windowSnapShadowSize", 24);
  config.windowSnapTitleHeightMode = KWin.readConfig("windowSnapTitleHeightMode", 0);
  config.windowSnapTitleHeight = KWin.readConfig("windowSnapTitleHeight", 32);
  config.windowSnapTitlePadding = KWin.readConfig("windowSnapTitlePadding", 6);
  config.windowSnapFontFamily = KWin.readConfig("windowSnapFontFamily", "");
  config.windowSnapFontSize = KWin.readConfig("windowSnapFontSize", 11);
  config.windowSnapFontBold = KWin.readConfig("windowSnapFontBold", true);
  config.windowSnapFontColor = KWin.readConfig("windowSnapFontColor", "#ffffff");
  config.windowSnapFontGlowEnabled = KWin.readConfig("windowSnapFontGlowEnabled", false);
  config.windowSnapFontGlowColor = KWin.readConfig("windowSnapFontGlowColor", "#ffffff");
  config.windowSnapFontGlowSize = KWin.readConfig("windowSnapFontGlowSize", 8);
  config.windowSnapFontShadowEnabled = KWin.readConfig("windowSnapFontShadowEnabled", true);
  config.windowSnapFontShadowColor = KWin.readConfig("windowSnapFontShadowColor", "#c0000000");
  config.windowSnapFontShadowSize = KWin.readConfig("windowSnapFontShadowSize", 6);
  config.layouts = layouts;
  config.filterMode = KWin.readConfig("filterMode", 0);
  config.filterList = KWin.readConfig("filterList", "");
  config.pollingRate = KWin.readConfig("pollingRate", 100);
  config.enableDebugLogging = KWin.readConfig("enableDebugLogging", false);
  config.enableDebugOverlay = KWin.readConfig("enableDebugOverlay", false);

  QML.root.config = config;

  console.log("KZones: Config loaded:", JSON.stringify(config));
}

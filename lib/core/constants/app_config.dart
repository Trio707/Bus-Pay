class AppConfig {
  static const apiPort = 3000;

  /// Prefer the PC Wi‑Fi LAN IP so a physical phone can reach Nest.
  /// ApiService probes hosts in order until /health responds.
  static const apiHosts = [
    'http://192.168.1.20:3000',
  ];
}

class AppConstants {
  // Supabase - Replace with your actual Supabase credentials
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';

  // FastAPI Backend
  // Local development: 'http://localhost:8000'
  // Render production: 'https://your-app-name.onrender.com'
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    //defaultValue: 'http://0.0.0.0:8000',
    defaultValue: 'https://backend-server-fast-prompt.onrender.com',
  );

  // App Info
  static const String appName = 'CrowdPulse AI';
  static const String appTagline = 'Predict Before You Step Out';
  static const double smartRouteRadiusKm = 12.0;

  // Dummy Locations for demo
  static const List<Map<String, dynamic>> demoLocations = [
    {
      'id': 'metro_a',
      'name': 'Metro Station A',
      'lat': 19.0760,
      'lng': 72.8777,
      'type': 'metro',
    },
    {
      'id': 'metro_b',
      'name': 'Metro Station B',
      'lat': 19.0590,
      'lng': 72.8360,
      'type': 'metro',
    },
    {
      'id': 'bus_stop_1',
      'name': 'Central Bus Stop',
      'lat': 19.0820,
      'lng': 72.8810,
      'type': 'bus',
    },
    {
      'id': 'mall_1',
      'name': 'City Mall',
      'lat': 19.0650,
      'lng': 72.8650,
      'type': 'mall',
    },
    {
      'id': 'park_1',
      'name': 'Green Park',
      'lat': 19.0700,
      'lng': 72.8500,
      'type': 'park',
    },
    {
      'id': 'station_1',
      'name': 'Railway Station',
      'lat': 19.0728,
      'lng': 72.8826,
      'type': 'railway',
    },
  ];
}

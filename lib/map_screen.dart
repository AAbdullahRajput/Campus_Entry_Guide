// =============================================================================
//  map_screen.dart  –  PMAS Campus Map  –  Complete Rewrite v4
//  Fixes:
//    ✅ Map tiles now visible (removed aggressive white filter)
//    ✅ Navigate panel with From/To tabs (tap map or use location)
//    ✅ Go button to start live journey
//    ✅ Live navigation: shrinking polyline + real-time ETA every 3s
//    ✅ Outside campus → From defaults to Main Gate
//    ✅ Inside campus → From defaults to current GPS
//    ✅ Beautiful PMAS green theme throughout
//    ✅ FIXED: invalid_constant — removed const from Text using _mainGateBuilding
//    ✅ NEW: White mask outside campus boundary — only campus area visible
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

// ─── Global Constants ──────────────────────────────────────────────────────────
const LatLng kCampusCenter = LatLng(33.6500, 73.0835);

const double kCampusNorth = 33.6515;
const double kCampusSouth = 33.6465;
const double kCampusEast  = 73.0858;
const double kCampusWest  = 73.0807;

// ─── Enums ──────────────────────────────────────────────────────────────────
enum NavigateTab { from, to }
enum SelectionMode { none, pickingFrom, pickingTo }

// ─── Theme Colors ───────────────────────────────────────────────────────────
const kGreen1 = Color(0xFF11998e);
const kGreen2 = Color(0xFF38ef7d);
const kOrange = Color(0xFFFF6B35);
const kCard   = Colors.white;

class EnhancedMapPage extends StatefulWidget {
  const EnhancedMapPage({super.key});
  @override
  State<EnhancedMapPage> createState() => _EnhancedMapPageState();
}

class _EnhancedMapPageState extends State<EnhancedMapPage>
    with TickerProviderStateMixin {
  // ── Controllers ─────────────────────────────────────────────────────────────
  final MapController         _mapController    = MapController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _fromController   = TextEditingController();
  final TextEditingController _toController     = TextEditingController();
  late AnimationController    _panelAnimCtrl;
  late Animation<double>      _panelAnim;

  // ── Map data ──────────────────────────────────────────────────────────────
  LatLng         _campusCenter         = kCampusCenter;
  List<LatLng>   _campusBoundaryPoints = [];
  List<Building> _buildings            = [];
  List<Building> _filteredBuildings    = [];
  List<Building> _favorites            = [];
  List<Building> _searchSuggestions    = [];
  List<Building> _toSuggestions        = [];
  List<Building> _fromSuggestions      = [];
  Building?      _mainGateBuilding;

  // ── Location ──────────────────────────────────────────────────────────────
  Position? _currentPosition;
  bool      _isOutsideCampus = false;

  // ── UI state ─────────────────────────────────────────────────────────────
  bool   _isLoading         = true;
  bool   _mapReady          = false;
  double _currentZoom       = 16.0;
  double _minAllowedZoom    = 14.0;  // updated after fitCamera runs
  bool   _showSuggestions   = false;
  bool   _showNavigatePanel = false;

  // ── Navigate Panel state ─────────────────────────────────────────────────
  NavigateTab   _activeTab     = NavigateTab.from;
  SelectionMode _selectionMode = SelectionMode.none;

  // From point
  LatLng? _fromLatLng;
  String  _fromLabel = '';

  // To point
  LatLng? _toLatLng;
  String  _toLabel = '';

  // ── Navigation / Journey ──────────────────────────────────────────────────
  bool         _isNavigating       = false;
  RouteData?   _currentRoute;
  bool         _isCalculatingRoute = false;
  double?      _remainingDistance;
  int?         _remainingTimeMinutes;
  List<LatLng> _livePolyline       = [];

  // ── Timer ──────────────────────────────────────────────────────────────────
  Timer? _locationTimer;

  // ── API ────────────────────────────────────────────────────────────────────
  final String _apiBaseUrl = 'http://192.168.100.63:3000/api/campus-map';

  final List<String> _debugLogs = [];

  // ═══════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    _panelAnimCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 350),
    );
    _panelAnim = CurvedAnimation(
      parent: _panelAnimCtrl,
      curve:  Curves.easeOutCubic,
    );
    _initializeMap();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _searchController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _mapController.dispose();
    _panelAnimCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  INIT
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _initializeMap() async {
    try {
      await _loadCampusData();
      await _getCurrentLocation();
    } catch (e) {
      _log('Init error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _startLocationTracking();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DATA
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _loadCampusData() async {
    try {
      final res = await http
          .get(Uri.parse('$_apiBaseUrl/init/main'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final data = json.decode(res.body) as Map<String, dynamic>;

      if (data['boundaries'] != null) {
        final pts = (data['boundaries']['points'] as List)
            .map((p) => LatLng(
                  double.parse(p['lat'].toString()),
                  double.parse(p['lng'].toString()),
                ))
            .toList();
        final c = data['boundaries']['center'];
        if (mounted) {
          setState(() {
            _campusBoundaryPoints = pts;
            _campusCenter = LatLng(
              double.parse(c['lat'].toString()),
              double.parse(c['lng'].toString()),
            );
          });
        }
      }

      final rawBuildings = data['buildings']['data'] as List;
      final parsed = <Building>[];
      for (final b in rawBuildings) {
        try { parsed.add(Building.fromJson(b as Map<String, dynamic>)); } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _buildings         = parsed;
          _filteredBuildings = parsed;
          _mainGateBuilding  = parsed.where((b) =>
            b.name.toLowerCase().contains('main gate') ||
            b.name.toLowerCase().contains('main entrance')
          ).firstOrNull;
        });
      }
      _log('Loaded ${parsed.length} buildings');
    } catch (e) {
      _log('Load error: $e', isError: true);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LOCATION
  // ═══════════════════════════════════════════════════════════════════════════
  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      _getCurrentLocation();
      if (_isNavigating) _updateLiveNavigation();
    });
  }

  bool _isOnCampus(Position p) {
    const double tol = 0.001;
    return p.latitude  >= kCampusSouth - tol &&
           p.latitude  <= kCampusNorth + tol &&
           p.longitude >= kCampusWest  - tol &&
           p.longitude <= kCampusEast  + tol;
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    try {
      final svc = await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 5));
      if (!svc) return;

      var perm = await Geolocator.checkPermission()
          .timeout(const Duration(seconds: 5));
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission()
            .timeout(const Duration(seconds: 15));
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      final onCampus = _isOnCampus(pos);
      if (mounted) {
        setState(() {
          _currentPosition = onCampus ? pos : null;
          _isOutsideCampus = !onCampus;
        });
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LIVE NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════
  void _updateLiveNavigation() {
    if (!mounted || _toLatLng == null || _livePolyline.isEmpty) return;

    final walkerPos = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : (_isOutsideCampus && _mainGateBuilding != null
            ? _mainGateBuilding!.location
            : null);

    if (walkerPos == null) return;

    final trimmed = _trimPolylineFromPosition(walkerPos, _livePolyline);
    if (trimmed.isEmpty) return;

    double remaining = 0;
    for (int i = 0; i < trimmed.length - 1; i++) {
      remaining += const Distance().distance(trimmed[i], trimmed[i + 1]);
    }
    final eta = (remaining / 1.4 / 60).ceil();

    if (mounted) {
      setState(() {
        _livePolyline         = trimmed;
        _remainingDistance    = remaining;
        _remainingTimeMinutes = eta;
      });
    }

    if (remaining < 25) {
      _onArrived();
    }
  }

  List<LatLng> _trimPolylineFromPosition(LatLng walker, List<LatLng> poly) {
    if (poly.length < 2) return poly;

    int    closestIdx = 0;
    double minDist    = double.infinity;

    for (int i = 0; i < poly.length; i++) {
      final d = const Distance().distance(walker, poly[i]);
      if (d < minDist) {
        minDist    = d;
        closestIdx = i;
      }
    }

    if (minDist > 200) return poly;
    return [walker, ...poly.sublist(closestIdx + 1)];
  }

  void _onArrived() {
    if (!mounted) return;
    _showSuccessSnackbar('🎉 You have arrived at your destination!');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  NAVIGATE PANEL
  // ═══════════════════════════════════════════════════════════════════════════
  void _openNavigatePanel() {
    if (_currentPosition != null) {
      _fromLatLng          = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
      _fromLabel           = 'My Location';
      _fromController.text = 'My Location';
    } else if (_isOutsideCampus && _mainGateBuilding != null) {
      _fromLatLng          = _mainGateBuilding!.location;
      _fromLabel           = _mainGateBuilding!.name;
      _fromController.text = _mainGateBuilding!.name;
    }

    setState(() {
      _showNavigatePanel = true;
      _activeTab         = NavigateTab.to;
      _selectionMode     = SelectionMode.none;
    });
    _panelAnimCtrl.forward();
  }

  void _closeNavigatePanel() {
    _panelAnimCtrl.reverse().then((_) {
      if (mounted) setState(() => _showNavigatePanel = false);
    });
    setState(() => _selectionMode = SelectionMode.none);
  }

  void _onMapTap(TapPosition tapPos, LatLng latlng) {
    if (_selectionMode == SelectionMode.pickingFrom) {
      setState(() {
        _fromLatLng          = latlng;
        _fromLabel           = '${latlng.latitude.toStringAsFixed(4)}, ${latlng.longitude.toStringAsFixed(4)}';
        _fromController.text = _fromLabel;
        _selectionMode       = SelectionMode.none;
        _activeTab           = NavigateTab.to;
      });
      _showSuccessSnackbar('✅ Start point selected');
    } else if (_selectionMode == SelectionMode.pickingTo) {
      setState(() {
        _toLatLng          = latlng;
        _toLabel           = '${latlng.latitude.toStringAsFixed(4)}, ${latlng.longitude.toStringAsFixed(4)}';
        _toController.text = _toLabel;
        _selectionMode     = SelectionMode.none;
      });
      _showSuccessSnackbar('✅ Destination selected');
    }
  }

  Future<void> _startJourney() async {
    if (_fromLatLng == null || _toLatLng == null) {
      _showErrorSnackbar('Please select both start and destination');
      return;
    }

    setState(() => _isCalculatingRoute = true);
    _closeNavigatePanel();

    final polylineCoords = [_fromLatLng!, _toLatLng!];
    final dist = const Distance().distance(_fromLatLng!, _toLatLng!);
    final eta  = (dist / 1.4 / 60).ceil();

    if (mounted) {
      setState(() {
        _isNavigating         = true;
        _isCalculatingRoute   = false;
        _livePolyline         = List.from(polylineCoords);
        _remainingDistance    = dist;
        _remainingTimeMinutes = eta;
        _currentRoute = RouteData(
          from: Building(
            id:           -1,
            name:         _fromLabel,
            location:     _fromLatLng!,
            campusType:   'main',
            isMajor:      false,
            categoryName: 'Start',
            categoryColor: '#11998e',
            categoryIcon:  'my_location',
          ),
          to: Building(
            id:           -2,
            name:         _toLabel,
            location:     _toLatLng!,
            campusType:   'main',
            isMajor:      false,
            categoryName: 'Destination',
            categoryColor: '#FF6B35',
            categoryIcon:  'location_on',
          ),
          routes: [
            CampusRoute(
              coordinates:          polylineCoords,
              distanceMeters:       dist.round(),
              estimatedTimeMinutes: eta,
              pathType:             'direct',
            ),
          ],
        );
      });
    }

    _fitBoundsToRoute(polylineCoords);
  }

  void _fitBoundsToRoute(List<LatLng> coords) {
    if (!_mapReady || coords.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints(coords);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(60),
        ),
      );
    } catch (_) {}
  }

  void _clearNavigation() {
    setState(() {
      _isNavigating         = false;
      _currentRoute         = null;
      _livePolyline         = [];
      _remainingDistance    = null;
      _remainingTimeMinutes = null;
      _fromLatLng           = null;
      _toLatLng             = null;
      _fromLabel            = '';
      _toLabel              = '';
      _fromController.clear();
      _toController.clear();
    });
  }

  // ─── From/To search ────────────────────────────────────────────────────────
  void _searchFrom(String q) {
    if (q.isEmpty) { setState(() => _fromSuggestions = []); return; }
    final ql = q.toLowerCase();
    setState(() {
      _fromSuggestions = _buildings
          .where((b) => b.name.toLowerCase().contains(ql))
          .take(6)
          .toList();
    });
  }

  void _searchTo(String q) {
    if (q.isEmpty) { setState(() => _toSuggestions = []); return; }
    final ql = q.toLowerCase();
    setState(() {
      _toSuggestions = _buildings
          .where((b) => b.name.toLowerCase().contains(ql))
          .take(6)
          .toList();
    });
  }

  void _searchBuildings(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredBuildings = _buildings;
        _searchSuggestions = [];
        _showSuggestions   = false;
      });
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _searchSuggestions = _buildings
          .where((b) =>
              b.name.toLowerCase().contains(q) ||
              b.categoryName.toLowerCase().contains(q))
          .toList();
      _showSuggestions = true;
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  void _safeMove(LatLng center, double zoom) {
    if (!mounted || !_mapReady) return;
    try {
      // Clamp zoom: never below fitted boundary zoom
      final clampedZoom = zoom.clamp(_minAllowedZoom, 19.0);
      // Clamp center within campus bounds
      final clampedCenter = LatLng(
        center.latitude.clamp(kCampusSouth, kCampusNorth),
        center.longitude.clamp(kCampusWest, kCampusEast),
      );
      _mapController.move(clampedCenter, clampedZoom);
    } catch (_) {}
  }

  // Snap map back to the locked fitted view (boundary centered with white space)
  void _snapToFittedView() {
    if (!mounted || !_mapReady) return;
    try { _mapController.move(_campusCenter, _minAllowedZoom); } catch (_) {}
  }

  void _showErrorSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: Colors.red,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccessSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: kGreen1,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  List<Building> _getVisibleBuildings() {
    return _filteredBuildings.where((b) {
      if (b.isMajor) return true;
      return _currentZoom >= (b.zoomLevelMin ?? 16.0);
    }).toList();
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return kGreen1;
    try {
      return Color(int.parse(hex.replaceAll('#', ''), radix: 16) + 0xFF000000);
    } catch (_) { return kGreen1; }
  }

  IconData _getIconData(String? name) {
    const map = {
      'admin_panel_settings': Icons.admin_panel_settings,
      'school':               Icons.school,
      'domain':               Icons.domain,
      'local_library':        Icons.local_library,
      'science':              Icons.science,
      'hotel':                Icons.hotel,
      'restaurant':           Icons.restaurant,
      'sports_soccer':        Icons.sports_soccer,
      'mosque':               Icons.mosque,
      'local_parking':        Icons.local_parking,
      'meeting_room':         Icons.meeting_room,
      'local_hospital':       Icons.local_hospital,
      'campaign':             Icons.campaign,
      'computer':             Icons.computer,
      'park':                 Icons.park,
      'my_location':          Icons.my_location,
      'train':                Icons.train,
      'location_on':          Icons.location_on,
    };
    return map[name] ?? Icons.location_on;
  }

  void _log(String msg, {bool isError = false}) {
    final ts    = DateTime.now().toIso8601String().substring(11, 23);
    final entry = '${isError ? "❌" : "✅"} [$ts] $msg';
    debugPrint(entry);
    if (mounted) setState(() {
      _debugLogs.add(entry);
      if (_debugLogs.length > 60) _debugLogs.removeAt(0);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? _buildLoadingScreen()
          : Column(
              children: [
                // ── TOP BAR (fixed height) ────────────────────────────────
                if (_selectionMode == SelectionMode.none)
                  _buildTopBar(),

                // ── MAP + OVERLAYS (fills all remaining space) ─────────────
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Map fills edge-to-edge; white mask handles outside boundary
                      _buildMap(),

                      // Selection hint overlay
                      if (_selectionMode != SelectionMode.none)
                        _buildSelectionHint(),

                      // Search suggestions dropdown
                      if (_showSuggestions && _searchSuggestions.isNotEmpty && _selectionMode == SelectionMode.none)
                        Positioned(
                          top: 8, left: 16, right: 16,
                          child: _buildSearchSuggestions(),
                        ),

                      // Navigate route panel (slides up from bottom)
                      if (_showNavigatePanel)
                        _buildNavigatePanel(),

                      // Live navigation info panel
                      if (_isNavigating && _currentRoute != null && !_showNavigatePanel)
                        Positioned(
                          bottom: 16,
                          left: 16, right: 16,
                          child: _buildLiveNavPanel(),
                        ),

                      // FABs (recenter + favorites)
                      if (!_isNavigating && !_showNavigatePanel && _selectionMode == SelectionMode.none)
                        Positioned(
                          bottom: 16, right: 16,
                          child: _buildFABs(),
                        ),
                    ],
                  ),
                ),

                // ── NAVIGATE BUTTON (fixed at very bottom) ─────────────────
                if (!_showNavigatePanel && _selectionMode == SelectionMode.none && !_isNavigating)
                  _buildBottomNavigateButton(),
              ],
            ),
    );
  }

  // ─── Loading ───────────────────────────────────────────────────────────────
  Widget _buildLoadingScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kGreen1, kGreen2],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            SizedBox(height: 24),
            Text('Loading Campus Map…',
                style: TextStyle(
                    color:         Colors.white,
                    fontSize:      18,
                    fontWeight:    FontWeight.w700,
                    letterSpacing: 0.5)),
            SizedBox(height: 8),
            Text('PMAS Arid Agriculture University',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ─── Map ───────────────────────────────────────────────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: kCampusCenter,
        initialZoom:   15.8,
        minZoom:       _minAllowedZoom,
        maxZoom:       19.0,
        // Tight constraint: center cannot leave a tiny box around campus center
        // This combined with minZoom = fitted zoom locks the map completely
        cameraConstraint: CameraConstraint.containCenter(
          bounds: LatLngBounds(
            const LatLng(kCampusSouth, kCampusWest),
            const LatLng(kCampusNorth, kCampusEast),
          ),
        ),
        onMapReady: () {
          if (!mounted) return;
          setState(() => _mapReady = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            try {
              // Fit campus boundary with equal padding on all 4 sides
              // This gives the "white space around campus" look
              final campusBounds = LatLngBounds(
                const LatLng(kCampusSouth, kCampusWest),
                const LatLng(kCampusNorth, kCampusEast),
              );
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds:  campusBounds,
                  padding: const EdgeInsets.all(30),
                ),
              );
              // Lock: capture exactly where fitCamera placed us
              final fittedZoom   = _mapController.camera.zoom;
              final fittedCenter = _mapController.camera.center;
              if (mounted) {
                setState(() {
                  _minAllowedZoom = fittedZoom;
                  _currentZoom    = fittedZoom;
                  _campusCenter   = fittedCenter; // lock pan center
                });
              }
            } catch (_) {}
          });
        },
        onPositionChanged: (pos, _) {
          if (!mounted) return;
          final z = pos.zoom ?? _minAllowedZoom;
          // If zoomed out past fitted level, snap back immediately
          if (z < _minAllowedZoom - 0.05 && _mapReady) {
            try {
              _mapController.move(_campusCenter, _minAllowedZoom);
            } catch (_) {}
          }
          setState(() => _currentZoom = z);
        },
        onTap: _onMapTap,
      ),
      children: [
        // ── REAL map tiles ──
        TileLayer(
          urlTemplate:          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pmas.campus_map',
        ),

        // ── Building footprints — hidden during navigation ──
        if (!_isNavigating)
        PolygonLayer(
          polygons: _getVisibleBuildings()
              .where((b) => b.polygonCoordinates != null && b.polygonCoordinates!.isNotEmpty)
              .map((b) => Polygon(
                    points:            b.polygonCoordinates!,
                    color:             _parseColor(b.categoryColor).withOpacity(0.30),
                    borderColor:       _parseColor(b.categoryColor),
                    borderStrokeWidth: 1.8,
                    isFilled:          true,
                  ))
              .toList(),
        ),

        // ── Live route polyline (shrinks) ──
        if (_isNavigating && _livePolyline.length >= 2)
          PolylineLayer(polylines: [
            Polyline(
              points:      _livePolyline,
              color:       Colors.black.withOpacity(0.15),
              strokeWidth: 9.0,
            ),
            Polyline(
              points:            _livePolyline,
              color:             kGreen1,
              strokeWidth:       6.0,
              borderColor:       Colors.white,
              borderStrokeWidth: 2.0,
            ),
          ]),

        // ── From pin (during navigation) ──
        if (_isNavigating && _fromLatLng != null)
          MarkerLayer(markers: [
            Marker(
              point:  _fromLatLng!,
              width:  40, height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color:  Colors.green,
                  shape:  BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 8)],
                ),
                child: const Icon(Icons.radio_button_checked, color: Colors.white, size: 18),
              ),
            ),
          ]),

        // ── To pin (during navigation) ──
        if (_isNavigating && _toLatLng != null)
          MarkerLayer(markers: [
            Marker(
              point:  _toLatLng!,
              width:  44, height: 60,
              child:  Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:  Colors.red,
                      shape:  BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                  ),
                  Container(width: 3, height: 10, color: Colors.red),
                ],
              ),
            ),
          ]),

        // ── Main Gate marker — hidden during navigation ──
        if (!_isNavigating && _isOutsideCampus && _mainGateBuilding != null)
          MarkerLayer(markers: [
            Marker(
              point: _mainGateBuilding!.location,
              width:  56, height: 76,
              child:  _buildMetroMarker(),
            ),
          ]),

        // ── Building markers — hidden during navigation for clean route view ──
        if (!_isNavigating)
        MarkerLayer(
          markers: _getVisibleBuildings().map((b) {
            return Marker(
              point:  b.location,
              width:  44,
              height: 64,
              child:  GestureDetector(
                onTap: () {
                  if (_selectionMode == SelectionMode.pickingFrom) {
                    setState(() {
                      _fromLatLng          = b.location;
                      _fromLabel           = b.name;
                      _fromController.text = b.name;
                      _selectionMode       = SelectionMode.none;
                      _activeTab           = NavigateTab.to;
                    });
                    _showSuccessSnackbar('✅ From: ${b.name}');
                  } else if (_selectionMode == SelectionMode.pickingTo) {
                    setState(() {
                      _toLatLng          = b.location;
                      _toLabel           = b.name;
                      _toController.text = b.name;
                      _selectionMode     = SelectionMode.none;
                    });
                    _showSuccessSnackbar('✅ To: ${b.name}');
                  } else {
                    _showBuildingDetails(b);
                  }
                },
                child: _buildBuildingMarker(b),
              ),
            );
          }).toList(),
        ),

        // ── GPS dot — hide during navigation (from/to pins are shown instead) ──
        if (!_isNavigating && _currentPosition != null)
          MarkerLayer(markers: [
            Marker(
              point:  LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              width:  44, height: 44,
              child:  Container(
                decoration: BoxDecoration(
                  color:  const Color(0xFF2196F3),
                  shape:  BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)],
                ),
                child: const Icon(Icons.navigation, color: Colors.white, size: 20),
              ),
            ),
          ]),

        // ── Map-tap pin indicators ──
        if (_selectionMode != SelectionMode.none && _fromLatLng != null && _selectionMode == SelectionMode.pickingTo)
          MarkerLayer(markers: [
            Marker(
              point: _fromLatLng!,
              width: 30, height: 30,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.circle, color: Colors.white, size: 12),
              ),
            ),
          ]),

        // ── WHITE MASK — paints white outside campus boundary ──────────────
        // This is what creates white on all 4 sides around the campus.
        if (_campusBoundaryPoints.length >= 3 && _mapReady)
          BoundaryMaskLayer(boundaryPoints: _campusBoundaryPoints),
      ],
    );
  }

  // ─── Markers ───────────────────────────────────────────────────────────────
  Widget _buildMetroMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color:  kGreen1,
            shape:  BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: kGreen1.withOpacity(0.5), blurRadius: 10)],
          ),
          padding: const EdgeInsets.all(9),
          child: const Icon(Icons.meeting_room, color: Colors.white, size: 22),
        ),
        Container(
          margin:  const EdgeInsets.only(top: 3),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color:        kGreen1,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('Main Gate',
              style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildBuildingMarker(Building b) {
    final showLabel = _currentZoom >= 17.5;
    final iconSize  = showLabel ? 38.0 : 44.0;

    return SizedBox(
      width:  44,
      height: 64,
      child: Column(
        mainAxisAlignment:  MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize:       MainAxisSize.max,
        children: [
          Container(
            width: iconSize, height: iconSize,
            decoration: BoxDecoration(
              color:  _parseColor(b.categoryColor),
              shape:  BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            alignment: Alignment.center,
            child: Icon(_getIconData(b.categoryIcon), color: Colors.white, size: showLabel ? 16 : 20),
          ),
          if (showLabel)
            Expanded(
              child: Container(
                width:   44,
                margin:  const EdgeInsets.only(top: 1),
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: Text(
                  b.name,
                  style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.black87),
                  maxLines:  2,
                  textAlign: TextAlign.center,
                  overflow:  TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Selection hint overlay ────────────────────────────────────────────────
  Widget _buildSelectionHint() {
    final isFrom = _selectionMode == SelectionMode.pickingFrom;
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Container(
          margin:  const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color:        isFrom ? kGreen1 : Colors.red,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Icon(isFrom ? Icons.radio_button_checked : Icons.location_on,
                  color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isFrom
                      ? 'Tap anywhere on the map to set your start point'
                      : 'Tap anywhere on the map to set your destination',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _selectionMode     = SelectionMode.none;
                  _showNavigatePanel = true;
                }),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kGreen1, kGreen2],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(
            color:     Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset:    const Offset(0, 5))],
      ),
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 8,
        bottom: 12, left: 16, right: 16,
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon:      const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  _locationTimer?.cancel();
                  if (mounted) Navigator.of(context).pop();
                },
              ),
              const Expanded(
                child: Text('PMAS Campus Map',
                    style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
              ),
              IconButton(
                icon:      const Icon(Icons.my_location, color: Colors.white),
                onPressed: () {
                  if (_currentPosition != null) {
                    _safeMove(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 18.0);
                  } else {
                    _safeMove(kCampusCenter, 16.0);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Search bar
          Material(
            elevation:    4,
            borderRadius: BorderRadius.circular(30),
            child: TextField(
              controller: _searchController,
              onChanged:  _searchBuildings,
              decoration: InputDecoration(
                hintText:   'Search buildings…',
                prefixIcon: const Icon(Icons.search, color: kGreen1),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon:      const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchBuildings('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide:   BorderSide.none),
                filled:         true,
                fillColor:      Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),

          if (_isOutsideCampus && !_isNavigating) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.train, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Outside campus — routes start from '
                      '${_mainGateBuilding?.name ?? 'Main Gate'}',
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _safeMove(kCampusCenter, 15.5),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('View',
                          style: TextStyle(
                              color:      kGreen1,
                              fontSize:   10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],


        ],
      ),
    );
  }

  // ─── Main search suggestions ───────────────────────────────────────────────
  Widget _buildSearchSuggestions() {
    return Material(
      elevation:    8,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: ListView.separated(
          shrinkWrap:       true,
          itemCount:        _searchSuggestions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final b = _searchSuggestions[i];
            return ListTile(
              dense: true,
              leading: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color:        _parseColor(b.categoryColor).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getIconData(b.categoryIcon), color: _parseColor(b.categoryColor), size: 20),
              ),
              title:    Text(b.name,         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(b.categoryName, style: const TextStyle(fontSize: 11)),
              trailing: IconButton(
                icon:      const Icon(Icons.navigation, color: kGreen1, size: 20),
                onPressed: () {
                  setState(() { _showSuggestions = false; _searchController.clear(); });
                  _toLatLng          = b.location;
                  _toLabel           = b.name;
                  _toController.text = b.name;
                  _openNavigatePanel();
                },
              ),
              onTap: () {
                setState(() { _showSuggestions = false; _searchController.clear(); });
                _safeMove(b.location, 18.5);
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) _showBuildingDetails(b);
                });
              },
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  NAVIGATE PANEL
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildNavigatePanel() {
    final readyToGo = _fromLatLng != null && _toLatLng != null;

    return AnimatedBuilder(
      animation: _panelAnim,
      builder: (_, child) => Positioned(
        bottom: 0, left: 0, right: 0,
        child: Transform.translate(
          offset: Offset(0, (1 - _panelAnim.value) * 600),
          child:  child,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 40, offset: const Offset(0, -10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  40, height: 4,
              margin: const EdgeInsets.only(top: 14, bottom: 6),
              decoration: BoxDecoration(
                color:        Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              margin:  const EdgeInsets.fromLTRB(16, 4, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kGreen1, kGreen2],
                  begin:  Alignment.centerLeft,
                  end:    Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.route, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan Your Route',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                      Text('Choose start & destination',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _closeNavigatePanel,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color:        Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildBeautifulField(
                      tab:            NavigateTab.from,
                      label:          'FROM',
                      hint:           'Choose start point…',
                      controller:     _fromController,
                      dotColor:       const Color(0xFF11998e),
                      icon:           Icons.radio_button_checked,
                      onSearchChanged: _searchFrom,
                      onPickFromMap: () => setState(() {
                        _selectionMode     = SelectionMode.pickingFrom;
                        _showNavigatePanel = false;
                      }),
                      onUseMyLocation: _currentPosition != null ? () {
                        setState(() {
                          _fromLatLng          = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
                          _fromLabel           = 'My Location';
                          _fromController.text = 'My Location';
                          _fromSuggestions     = [];
                          _activeTab           = NavigateTab.to;
                        });
                      } : null,
                      suggestions: _activeTab == NavigateTab.from ? _fromSuggestions : [],
                      onSelectSuggestion: (b) => setState(() {
                        _fromLatLng          = b.location;
                        _fromLabel           = b.name;
                        _fromController.text = b.name;
                        _fromSuggestions     = [];
                        _activeTab           = NavigateTab.to;
                      }),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                final tmpLatLng      = _fromLatLng;
                                final tmpLabel       = _fromLabel;
                                _fromLatLng          = _toLatLng;
                                _fromLabel           = _toLabel;
                                _fromController.text = _toLabel;
                                _toLatLng            = tmpLatLng;
                                _toLabel             = tmpLabel ?? '';
                                _toController.text   = tmpLabel ?? '';
                              });
                            },
                            child: Container(
                              margin:  const EdgeInsets.symmetric(horizontal: 10),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color:  Colors.white,
                                shape:  BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)],
                              ),
                              child: const Icon(Icons.swap_vert, size: 16, color: kGreen1),
                            ),
                          ),
                          Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
                        ],
                      ),
                    ),

                    _buildBeautifulField(
                      tab:            NavigateTab.to,
                      label:          'TO',
                      hint:           'Search destination…',
                      controller:     _toController,
                      dotColor:       Colors.red,
                      icon:           Icons.location_on,
                      onSearchChanged: _searchTo,
                      onPickFromMap: () => setState(() {
                        _selectionMode     = SelectionMode.pickingTo;
                        _showNavigatePanel = false;
                      }),
                      onUseMyLocation: null,
                      suggestions: _activeTab == NavigateTab.to ? _toSuggestions : [],
                      onSelectSuggestion: (b) => setState(() {
                        _toLatLng          = b.location;
                        _toLabel           = b.name;
                        _toController.text = b.name;
                        _toSuggestions     = [];
                      }),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: readyToGo
                        ? [kGreen1, kGreen2]
                        : [Colors.grey.shade300, Colors.grey.shade300],
                    begin: Alignment.centerLeft,
                    end:   Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: readyToGo
                      ? [BoxShadow(color: kGreen1.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap:        readyToGo ? _startJourney : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      child: _isCalculatingRoute
                          ? const Center(child: SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.directions_walk,
                                    color: readyToGo ? Colors.white : Colors.grey.shade500,
                                    size:  22),
                                const SizedBox(width: 10),
                                Text(
                                  readyToGo ? 'Start Journey' : 'Select start & destination',
                                  style: TextStyle(
                                    color:         readyToGo ? Colors.white : Colors.grey.shade500,
                                    fontSize:      16,
                                    fontWeight:    FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBeautifulField({
    required NavigateTab            tab,
    required String                 label,
    required String                 hint,
    required TextEditingController  controller,
    required Color                  dotColor,
    required IconData               icon,
    required ValueChanged<String>   onSearchChanged,
    required VoidCallback           onPickFromMap,
    required VoidCallback?          onUseMyLocation,
    required List<Building>         suggestions,
    required ValueChanged<Building> onSelectSuggestion,
  }) {
    final isActive = _activeTab == tab;

    return GestureDetector(
      onTap: () => setState(() => _activeTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:  const EdgeInsets.fromLTRB(16, 12, 16, 0),
        decoration: BoxDecoration(
          color:        isActive ? dotColor.withOpacity(0.04) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: dotColor.withOpacity(0.4), blurRadius: 6, spreadRadius: 1)],
                  ),
                ),
                const SizedBox(width: 10),
                Text(label,
                    style: TextStyle(
                      color:         dotColor,
                      fontSize:      10,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: 1.8,
                    )),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 4, bottom: 10),
              child: TextField(
                controller: controller,
                onTap:      () => setState(() => _activeTab = tab),
                onChanged:  onSearchChanged,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                decoration: InputDecoration(
                  isDense:  true,
                  hintText: hint,
                  hintStyle: TextStyle(
                      color:      Colors.grey.shade400,
                      fontSize:   14,
                      fontWeight: FontWeight.w400),
                  border:         InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (isActive) ...[
              Padding(
                padding: const EdgeInsets.only(left: 22, bottom: 12),
                child: Row(
                  children: [
                    _chipBtn(Icons.map_outlined, 'Pick on map', dotColor, onPickFromMap),
                    if (onUseMyLocation != null) ...[
                      const SizedBox(width: 8),
                      _chipBtn(Icons.my_location, 'My location', Colors.blue, onUseMyLocation!),
                    ],
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 0),
            if (isActive && suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 22, bottom: 12),
                decoration: BoxDecoration(
                  color:        Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics:    const NeverScrollableScrollPhysics(),
                  itemCount:  suggestions.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                  itemBuilder: (_, i) {
                    final b = suggestions[i];
                    return InkWell(
                      onTap: () => onSelectSuggestion(b),
                      borderRadius: i == 0
                          ? const BorderRadius.vertical(top: Radius.circular(14))
                          : i == suggestions.length - 1
                              ? const BorderRadius.vertical(bottom: Radius.circular(14))
                              : BorderRadius.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color:        _parseColor(b.categoryColor).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(_getIconData(b.categoryIcon),
                                  color: _parseColor(b.categoryColor), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.name,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis),
                                  Text(b.categoryName,
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _chipBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ─── Live navigation panel ─────────────────────────────────────────────────
  Widget _buildLiveNavPanel() {
    final dist    = _remainingDistance;
    final eta     = _remainingTimeMinutes;
    final arrived = dist != null && dist < 25;

    return Material(
      elevation:    16,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kGreen1, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [kGreen1, kGreen2]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.navigation, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Live Navigation',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kGreen1)),
                ),
                IconButton(
                  icon:      const Icon(Icons.center_focus_strong, color: kGreen1),
                  onPressed: () {
                    if (_currentPosition != null) {
                      _safeMove(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 17.0);
                    } else if (_fromLatLng != null) {
                      _safeMove(_fromLatLng!, 16.0);
                    }
                  },
                ),
                IconButton(
                  icon:      const Icon(Icons.close, color: Colors.grey),
                  onPressed: _clearNavigation,
                ),
              ],
            ),

            Row(
              children: [
                const Icon(Icons.radio_button_checked, color: Colors.green, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _fromLabel.isNotEmpty ? _fromLabel : 'Start',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.grey, size: 14),
                const SizedBox(width: 6),
                const Icon(Icons.location_on, color: Colors.red, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _toLabel.isNotEmpty ? _toLabel : 'Destination',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            if (arrived)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:        Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kGreen1),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: kGreen1, size: 26),
                    SizedBox(width: 10),
                    Text('You have arrived! 🎉',
                        style: TextStyle(color: kGreen1, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color:        Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _navStat(Icons.straighten,
                        dist != null ? _formatDistance(dist) : '—', 'Remaining', Colors.blue),
                    Container(width: 1, height: 40, color: Colors.grey.shade300),
                    _navStat(Icons.access_time,
                        eta != null ? '$eta min' : '—', 'ETA', kOrange),
                    Container(width: 1, height: 40, color: Colors.grey.shade300),
                    _navStat(Icons.directions_walk, 'Walking', 'Mode', kGreen1),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double d) {
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)} km';
    return '${d.toStringAsFixed(0)} m';
  }

  Widget _navStat(IconData icon, String value, String label, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
    ]);
  }

  // ─── Bottom Navigate Button ───────────────────────────────────────────────
  Widget _buildBottomNavigateButton() {
    return GestureDetector(
      onTap: _openNavigatePanel,
      child: Container(
        width:   double.infinity,
        padding: EdgeInsets.fromLTRB(
          0, 18, 0,
          18 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kGreen1, kGreen2],
            begin:  Alignment.centerLeft,
            end:    Alignment.centerRight,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.navigation_rounded, color: Colors.white, size: 24),
            SizedBox(width: 10),
            Text(
              'Navigate',
              style: TextStyle(
                color:         Colors.white,
                fontSize:      18,
                fontWeight:    FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FABs ──────────────────────────────────────────────────────────────────
  Widget _buildFABs() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag:         'recenter',
          mini:            true,
          backgroundColor: Colors.white,
          elevation:       4,
          onPressed: () => _snapToFittedView(),
          child: const Icon(Icons.center_focus_strong, color: kGreen1),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag:         'favorites',
          backgroundColor: const Color(0xFFFF5722),
          foregroundColor: Colors.white,
          elevation:       4,
          onPressed:       _showFavoritesSheet,
          child: const Icon(Icons.favorite),
        ),
      ],
    );
  }

  // ─── Building detail sheet ─────────────────────────────────────────────────
  void _showBuildingDetails(Building b) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:       MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _parseColor(b.categoryColor),
                    _parseColor(b.categoryColor).withOpacity(0.7)
                  ]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_getIconData(b.categoryIcon), color: Colors.white, size: 34),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:        _parseColor(b.categoryColor).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(b.categoryName,
                        style: TextStyle(
                            color:      _parseColor(b.categoryColor),
                            fontSize:   12,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
            ]),
            if (b.description != null && b.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(b.description!, style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5)),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _toLatLng          = b.location;
                    _toLabel           = b.name;
                    _toController.text = b.name;
                  });
                  _openNavigatePanel();
                },
                icon:  const Icon(Icons.navigation, size: 20),
                label: const Text('Navigate Here',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen1,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      if (_favorites.contains(b)) {
                        _favorites.remove(b);
                        _showSuccessSnackbar('Removed from favorites');
                      } else {
                        _favorites.add(b);
                        _showSuccessSnackbar('Added to favorites ♥');
                      }
                    });
                  },
                  icon:  Icon(_favorites.contains(b) ? Icons.favorite : Icons.favorite_border,
                      color: Colors.red),
                  label: Text(_favorites.contains(b) ? 'Saved' : 'Save',
                      style: const TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side:    const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(context); _safeMove(b.location, 19.0); },
                  icon:  const Icon(Icons.zoom_in, color: kGreen1),
                  label: const Text('Zoom In', style: TextStyle(color: kGreen1)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side:    const BorderSide(color: kGreen1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  // ─── Favorites ─────────────────────────────────────────────────────────────
  void _showFavoritesSheet() {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [kGreen1, kGreen2]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: const Row(children: [
                Icon(Icons.favorite, color: Colors.white, size: 26),
                SizedBox(width: 12),
                Text('Favorites',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ),
            Expanded(
              child: _favorites.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite_border, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No favorites yet',
                              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding:          const EdgeInsets.all(16),
                      itemCount:        _favorites.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final b = _favorites[i];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:        _parseColor(b.categoryColor).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_getIconData(b.categoryIcon),
                                color: _parseColor(b.categoryColor), size: 24),
                          ),
                          title:    Text(b.name,         style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(b.categoryName),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon:      const Icon(Icons.navigation, color: kGreen1),
                                onPressed: () {
                                  Navigator.pop(context);
                                  setState(() {
                                    _toLatLng          = b.location;
                                    _toLabel           = b.name;
                                    _toController.text = b.name;
                                  });
                                  _openNavigatePanel();
                                },
                              ),
                              IconButton(
                                icon:      const Icon(Icons.favorite, color: Colors.red),
                                onPressed: () {
                                  setState(() => _favorites.remove(b));
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                          onTap: () { Navigator.pop(context); _safeMove(b.location, 18.5); },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}


// =============================================================================
//  BOUNDARY MASK — whites out everything OUTSIDE the campus polygon
// =============================================================================
class BoundaryMaskLayer extends StatelessWidget {
  final List<LatLng> boundaryPoints;
  const BoundaryMaskLayer({super.key, required this.boundaryPoints});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _BoundaryMaskPainter(
            boundaryPoints: boundaryPoints,
            camera:         camera,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BoundaryMaskPainter extends CustomPainter {
  final List<LatLng> boundaryPoints;
  final MapCamera    camera;

  _BoundaryMaskPainter({required this.boundaryPoints, required this.camera});

  @override
  void paint(Canvas canvas, Size size) {
    if (boundaryPoints.isEmpty) return;

    // Convert LatLng → screen pixels
    final screenPts = boundaryPoints.map((ll) {
      final pt = camera.latLngToScreenPoint(ll);
      return Offset(pt.x.toDouble(), pt.y.toDouble());
    }).toList();

    // Build campus polygon path
    final campusPath = Path();
    campusPath.moveTo(screenPts.first.dx, screenPts.first.dy);
    for (int i = 1; i < screenPts.length; i++) {
      campusPath.lineTo(screenPts[i].dx, screenPts[i].dy);
    }
    campusPath.close();

    // saveLayer so BlendMode.clear works correctly
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Step 1: flood white over entire canvas
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Step 2: cut out the campus shape (reveals map tiles underneath)
    canvas.drawPath(
      campusPath,
      Paint()
        ..blendMode = BlendMode.clear
        ..style     = PaintingStyle.fill,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoundaryMaskPainter old) =>
      old.camera != camera || old.boundaryPoints != boundaryPoints;
}

// =============================================================================
//  DATA MODELS
// =============================================================================
class Building {
  final int     id;
  final String  name;
  final LatLng  location;
  final String  campusType;
  final String? description;
  final bool    isMajor;
  final String  categoryName;
  final String? categoryIcon;
  final String? categoryColor;
  final double? zoomLevelMin;
  final List<LatLng>? polygonCoordinates;

  const Building({
    required this.id,
    required this.name,
    required this.location,
    required this.campusType,
    this.description,
    required this.isMajor,
    required this.categoryName,
    this.categoryIcon,
    this.categoryColor,
    this.zoomLevelMin,
    this.polygonCoordinates,
  });

  factory Building.fromJson(Map<String, dynamic> j) {
    List<LatLng>? poly;
    if (j['polygon_coordinates'] is List) {
      try {
        poly = (j['polygon_coordinates'] as List)
            .map((p) => LatLng(
                  double.parse(p['lat'].toString()),
                  double.parse(p['lng'].toString()),
                ))
            .toList();
      } catch (_) {}
    }
    return Building(
      id:            j['id'] as int,
      name:          j['name'] as String,
      location:      LatLng(
        double.parse(j['latitude'].toString()),
        double.parse(j['longitude'].toString()),
      ),
      campusType:    j['campus_type']  as String? ?? 'main',
      description:   j['description'] as String?,
      isMajor:       j['is_major_building'] == 1 || j['is_major_building'] == true,
      categoryName:  j['category_name'] as String? ?? 'Unknown',
      categoryIcon:  j['category_icon']  as String?,
      categoryColor: j['category_color'] as String?,
      zoomLevelMin:  j['zoom_level_min'] != null
          ? double.tryParse(j['zoom_level_min'].toString())
          : null,
      polygonCoordinates: poly,
    );
  }

  @override
  bool operator ==(Object other) => other is Building && id == other.id;
  @override
  int get hashCode => id.hashCode;
}

class RouteData {
  final Building          from, to;
  final List<CampusRoute> routes;
  const RouteData({required this.from, required this.to, required this.routes});
  List<LatLng> get coordinates => routes.first.coordinates;
}

class CampusRoute {
  final List<LatLng> coordinates;
  final int          distanceMeters;
  final int          estimatedTimeMinutes;
  final String       pathType;
  const CampusRoute({
    required this.coordinates,
    required this.distanceMeters,
    required this.estimatedTimeMinutes,
    required this.pathType,
  });
}
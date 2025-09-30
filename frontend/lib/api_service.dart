// lib/api_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Wingrow Inventory/Claims API client
/// - Uses a single reusable http.Client
/// - Adds 20s request timeout
/// - Manages Bearer token via SharedPreferences
/// - Provides typed helpers for common endpoints
class ApiService {
  final String baseUrl; // e.g. https://wingrow-inventory.onrender.com
  final http.Client _client = http.Client();

  ApiService(this.baseUrl);

  // ---------- Storage keys ----------
  static const _kToken = 'auth_token';
  static const _kRole = 'auth_role';
  static const _kUserId = 'auth_userId';

  // ---------- Timeouts / helpers ----------
  static const _defaultTimeout = Duration(seconds: 20);

  Future<http.Response> _withTimeout(Future<http.Response> f) =>
      f.timeout(_defaultTimeout);

  Map<String, String> _jsonHeaders([Map<String, String>? extra]) => {
        'Content-Type': 'application/json',
        if (extra != null) ...extra,
      };

  String _u(String path) =>
      path.startsWith('http') ? path : '$baseUrl$path'; // join base + path

  // ---------- Auth storage ----------
  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<void> _saveAuth({
    required String token,
    Map<String, dynamic>? user,
  }) async {
    final p = await _prefs();
    await p.setString(_kToken, token);
    await p.setString(_kRole, user?['role']?.toString() ?? '');
    await p.setString(_kUserId, user?['userId']?.toString() ?? '');
  }

  Future<void> _clearAuth() async {
    final p = await _prefs();
    await p.remove(_kToken);
    await p.remove(_kRole);
    await p.remove(_kUserId);
  }

  Future<String?> _getToken() async => (await _prefs()).getString(_kToken);
  Future<String?> getStoredRole() async => (await _prefs()).getString(_kRole);
  Future<String?> getStoredUserId() async =>
      (await _prefs()).getString(_kUserId);

  Future<Map<String, String>> _authHeaders({Map<String, String>? extra}) async {
    final t = await _getToken();
    return {
      ..._jsonHeaders(extra),
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  // ---------- Generic HTTP helpers ----------
  Future<http.Response> get(String path) async => _withTimeout(
        _client.get(Uri.parse(_u(path)), headers: await _authHeaders()),
      );

  Future<http.Response> post(String path, Map<String, dynamic> body) async =>
      _withTimeout(
        _client.post(
          Uri.parse(_u(path)),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        ),
      );

  Future<http.Response> patch(String path, Map<String, dynamic> body) async =>
      _withTimeout(
        _client.patch(
          Uri.parse(_u(path)),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        ),
      );

  Future<http.Response> del(String path) async => _withTimeout(
        _client.delete(Uri.parse(_u(path)), headers: await _authHeaders()),
      );

  // Public: close the client when no longer needed
  void dispose() => _client.close();

  // ==================== AUTH ====================

  /// POST /api/auth/login  -> { token, user }
  Future<bool> login(String userId, String password) async {
    final res = await post('/api/auth/login', {
      'userId': userId,
      'password': password,
    });
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token != null && token.isNotEmpty) {
        final user = (data['user'] as Map?)?.cast<String, dynamic>();
        await _saveAuth(token: token, user: user);
        return true;
      }
    }
    return false;
  }

  /// POST /api/auth/logout  (best-effort), then clear local storage
  Future<void> logout() async {
    try {
      await _withTimeout(
        _client.post(Uri.parse(_u('/api/auth/logout')),
            headers: await _authHeaders()),
      );
    } catch (_) {
      // ignore network errors on logout
    } finally {
      await _clearAuth();
    }
  }

  /// GET /api/auth/me
  Future<http.Response> me() => get('/api/auth/me');

  // ==================== CLAIMS ====================

  /// POST /api/claims  -> returns claimId
  Future<String?> createClaim() async {
    final r = await post('/api/claims', {});
    if (r.statusCode == 200) {
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      return m['claimId'] as String?;
    }
    return null;
  }

  /// POST /api/claims/:claimId/items  -> { ... } 200
  Future<bool> addClaimItem(String claimId, Map<String, dynamic> item) async {
    final r = await post('/api/claims/$claimId/items', item);
    return r.statusCode == 200;
  }

  /// POST /api/claims/:claimId/submit
  Future<bool> submitClaim(String claimId) async {
    final r = await post('/api/claims/$claimId/submit', {});
    return r.statusCode == 200;
  }

  /// GET /api/claims?mine=true
  Future<http.Response> myClaims() => get('/api/claims?mine=true');

  /// GET /api/claims/:claimId
  Future<http.Response> getClaim(String claimId) => get('/api/claims/$claimId');

  /// DELETE /api/claims/:claimId/items/:index
  Future<http.Response> deleteDraftItem(String claimId, int index) =>
      del('/api/claims/$claimId/items/$index');

  /// GET /api/claims/approvals?status=SUBMITTED|APPROVED|REJECTED
// lib/api_service.dart
  Future<http.Response> approvalsByStatus(
    String status, {
    bool includePaid = false,
    bool all = false,
  }) {
    final q = StringBuffer('/api/claims/approvals?status=$status');
    if (includePaid) q.write('&includePaid=true');
    if (all) q.write('&all=true');
    return get(q.toString());
  }

  /// POST /api/claims/:claimId/approve  { comment }
  Future<http.Response> approveClaim(String claimId, {String? comment}) =>
      post('/api/claims/$claimId/approve', {'comment': comment ?? ''});

  /// POST /api/claims/:claimId/reject  { comment }
  Future<http.Response> rejectClaim(String claimId, {String? comment}) =>
      post('/api/claims/$claimId/reject', {'comment': comment ?? ''});

  /// POST /api/claims/:claimId/mark-paid  { paymentRef }
  Future<http.Response> markPaid(String claimId, {String? paymentRef}) =>
      post('/api/claims/$claimId/mark-paid', {'paymentRef': paymentRef ?? ''});

  // ==================== UPLOADS ====================

  /// POST /api/uploads (multipart)
  /// Returns full URL (baseUrl + returned path) or null.
  Future<String?> uploadReceiptBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    final t = await _getToken();
    final req = http.MultipartRequest('POST', Uri.parse(_u('/api/uploads')));
    if (t != null && t.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $t';
    }
    req.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: filename),
    );
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final url = m['url'] as String?;
      if (url == null) return null;
      // Backend returns relative path (e.g., /uploads/xyz.jpg)
      // Make it absolute so UI can load it directly.
      return url.startsWith('http') ? url : _u(url);
    }
    return null;
  }

  // ==================== INVENTORY ====================

  /// GET /api/inventory/items
  Future<http.Response> listInventoryItems() => get('/api/inventory/items');

  Future<http.Response> updateInventoryItem(
    String id, {
    int? stock,
    double? unitPrice,
    String? name,
    String? uom,
    int? minQty,
  }) {
    final body = <String, dynamic>{
      if (stock != null) 'stock': stock,
      if (unitPrice != null) ...{
        'unitPrice': unitPrice, // preferred
        'price': unitPrice, // legacy field (safe no-op if backend ignores)
      },
      if (name != null) 'name': name,
      if (uom != null) 'uom': uom,
      if (minQty != null) 'minQty': minQty,
    };
    return patch('/api/inventory/items/$id', body);
  }

  /// POST /api/inventory/seed
  Future<http.Response> seedInventory() => post('/api/inventory/seed', {});

  // ----- Issue Requests -----

  /// Organizer: POST /api/inventory/requests  { itemId, qty, note? }
  Future<http.Response> createIssueRequest({
    required String itemId,
    required int qty,
    String? notes,
  }) =>
      post('/api/inventory/requests', {
        'itemId': itemId,
        'qty': qty,
        if (notes != null) 'note': notes,
      });

  /// Organizer: GET /api/inventory/requests?mine=true
  Future<http.Response> myIssueRequests() =>
      get('/api/inventory/requests?mine=true');

  /// Manager: GET /api/inventory/requests?status=PENDING|APPROVED|REJECTED
  Future<http.Response> issueRequestsByStatus(String status) =>
      get('/api/inventory/requests?status=$status');

  /// Manager: POST /api/inventory/requests/:id/approve  { issueQty?, note }
  // Amount due can be set when approving
  Future<http.Response> approveIssueRequest(
    String requestId, {
    int? issueQty,
    String? note,
    double? amountDue, // <- NEW
  }) =>
      post('/api/inventory/requests/$requestId/approve', {
        if (issueQty != null) 'issueQty': issueQty,
        'note': note ?? '',
        if (amountDue != null) 'amountDue': amountDue,
      });

// Organizer uploads payment proof (after using uploadReceiptBytes)
  Future<http.Response> addIssuePayment({
    required String requestId,
    required double amount,
    required String proofUrl,
    String? note,
  }) =>
      post('/api/inventory/requests/$requestId/payments', {
        'amount': amount,
        'proofUrl': proofUrl,
        'note': note ?? '',
      });

  /// Manager: POST /api/inventory/requests/:id/reject  { note }
  Future<http.Response> rejectIssueRequest(String requestId, {String? note}) =>
      post('/api/inventory/requests/$requestId/reject', {
        'note': note ?? '',
      });
}

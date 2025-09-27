// lib/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl; // e.g. http://localhost:4000  (10.0.2.2 for Android)
  ApiService(this.baseUrl);

  // -------------------- AUTH --------------------
  Future<bool> login(String userId, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        final user = (data['user'] as Map?)?.cast<String, dynamic>();
        await prefs.setString('auth_role', user?['role']?.toString() ?? '');
        await prefs.setString('auth_userId', user?['userId']?.toString() ?? '');
        return true;
      }
    }
    return false;
  }

  Future<void> logout() async {
    try {
      await http.post(Uri.parse('$baseUrl/api/auth/logout'));
    } catch (_) {}
    final p = await SharedPreferences.getInstance();
    await p.remove('auth_token');
    await p.remove('auth_role');
    await p.remove('auth_userId');
  }

  Future<String?> _getToken() async =>
      (await SharedPreferences.getInstance()).getString('auth_token');
  Future<String?> getStoredRole() async =>
      (await SharedPreferences.getInstance()).getString('auth_role');
  Future<String?> getStoredUserId() async =>
      (await SharedPreferences.getInstance()).getString('auth_userId');

  Future<Map<String, String>> _authHeaders({Map<String, String>? extra}) async {
    final t = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
      ...?extra,
    };
  }

  // -------------------- HTTP helpers --------------------
  Future<http.Response> get(String path) async =>
      http.get(Uri.parse('$baseUrl$path'), headers: await _authHeaders());

  Future<http.Response> post(String path, Map<String, dynamic> body) async =>
      http.post(Uri.parse('$baseUrl$path'),
          headers: await _authHeaders(), body: jsonEncode(body));

  Future<http.Response> patch(String path, Map<String, dynamic> body) async =>
      http.patch(Uri.parse('$baseUrl$path'),
          headers: await _authHeaders(), body: jsonEncode(body));

  Future<http.Response> del(String path) async =>
      http.delete(Uri.parse('$baseUrl$path'), headers: await _authHeaders());

  // -------------------- AUTH info --------------------
  Future<http.Response> me() => get('/api/auth/me');

  // -------------------- CLAIMS --------------------
  Future<String?> createClaim() async {
    final r = await post('/api/claims', {});
    if (r.statusCode == 200) {
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      return m['claimId'] as String?;
    }
    return null;
  }

  Future<bool> addClaimItem(String claimId, Map<String, dynamic> item) async {
    final r = await post('/api/claims/$claimId/items', item);
    return r.statusCode == 200;
  }

  Future<bool> submitClaim(String claimId) async {
    final r = await post('/api/claims/$claimId/submit', {});
    return r.statusCode == 200;
  }

  Future<http.Response> myClaims() => get('/api/claims?mine=true');
  Future<http.Response> getClaim(String claimId) => get('/api/claims/$claimId');
  Future<http.Response> deleteDraftItem(String claimId, int index) =>
      del('/api/claims/$claimId/items/$index');

  // Manager approvals
  Future<http.Response> approvalsByStatus(String status) => get(
      '/api/claims/approvals?status=$status'); // SUBMITTED|APPROVED|REJECTED
  Future<http.Response> approveClaim(String claimId, {String? comment}) =>
      post('/api/claims/$claimId/approve', {'comment': comment ?? ''});
  Future<http.Response> rejectClaim(String claimId, {String? comment}) =>
      post('/api/claims/$claimId/reject', {'comment': comment ?? ''});
  Future<http.Response> markPaid(String claimId, {String? paymentRef}) =>
      post('/api/claims/$claimId/mark-paid', {'paymentRef': paymentRef ?? ''});

  // -------------------- UPLOAD (bytes; Web-safe) --------------------
  Future<String?> uploadReceiptBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    final t = await _getToken();
    final req =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/api/uploads'));
    if (t != null) req.headers['Authorization'] = 'Bearer $t';
    req.files
        .add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode == 200) {
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final url = m['url'] as String?;
      return url == null ? null : ('$baseUrl$url');
    }
    return null;
  }

  // ==================== INVENTORY ====================

  /// List all inventory items.
  Future<http.Response> listInventoryItems() => get('/api/inventory/items');

  /// PATCH /api/inventory/items/:id { stock: <int> }
  /// (Backend expects `stock`, not `qty`.)
  Future<http.Response> updateItemStock(String id, int stock) =>
      patch('/api/inventory/items/$id', {'stock': stock});

  /// POST /api/inventory/seed {}
  Future<http.Response> seedInventory() => post('/api/inventory/seed', {});

  // ----- Issue requests -----
  /// Organizer: create a request to issue an item.
  Future<http.Response> createIssueRequest({
    required String itemId,
    required int qty,
    String? notes,
  }) =>
      post('/api/inventory/requests',
          {'itemId': itemId, 'qty': qty, if (notes != null) 'note': notes});

  /// Organizer: view my requests.
  Future<http.Response> myIssueRequests() =>
      get('/api/inventory/requests?mine=true');

  /// Manager: list by status: PENDING | APPROVED | REJECTED
  Future<http.Response> issueRequestsByStatus(String status) =>
      get('/api/inventory/requests?status=$status');

  /// Manager: approve (optional: override issued qty) + note.
  Future<http.Response> approveIssueRequest(
    String requestId, {
    int? issueQty,
    String? note,
  }) =>
      post('/api/inventory/requests/$requestId/approve',
          {if (issueQty != null) 'issueQty': issueQty, 'note': note ?? ''});

  /// Manager: reject with optional reason.
  Future<http.Response> rejectIssueRequest(String requestId, {String? note}) =>
      post('/api/inventory/requests/$requestId/reject', {'note': note ?? ''});
}

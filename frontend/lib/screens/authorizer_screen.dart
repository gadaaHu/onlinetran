import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/api_client.dart';

class AuthorizerScreen extends StatefulWidget {
  const AuthorizerScreen({super.key});

  @override
  State<AuthorizerScreen> createState() => _AuthorizerScreenState();
}

class _AuthorizerScreenState extends State<AuthorizerScreen> {
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  String? _error;
  String _filterQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await ApiClient.getToken();
      final uri = Uri.parse('${ApiClient.baseUrl}/auth/students');
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List) {
          setState(() {
            _students = List<Map<String, dynamic>>.from(data);
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to load students (${resp.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _loading = false;
      });
    }
  }

  Future<void> _confirmStudent(String userId, String name) async {
    try {
      final token = await ApiClient.getToken();
      final uri = Uri.parse('${ApiClient.baseUrl}/auth/confirm-student/$userId');
      final resp = await http.post(uri, headers: {
        'Authorization': 'Bearer $token',
      });

      if (resp.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $name has been confirmed successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
        _loadStudents();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Confirmation failed (${resp.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectStudent(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131326),
        title: const Text('Reject Student?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to reject and remove $name?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await ApiClient.getToken();
      final uri = Uri.parse('${ApiClient.baseUrl}/auth/reject-student/$userId');
      final resp = await http.post(uri, headers: {
        'Authorization': 'Bearer $token',
      });

      if (resp.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Student status updated: $name'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        _loadStudents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingCount = _students.where((s) => s['isConfirmed'] != true).length;
    final approvedCount = _students.where((s) => s['isConfirmed'] == true).length;

    final filtered = _students.where((s) {
      if (_filterQuery.isEmpty) return true;
      final q = _filterQuery.toLowerCase();
      final name = (s['fullName'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🛡️', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'Student Authorization',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : const Color(0xFF0F0F1A),
                  ),
                ),
              ],
            ),
            Text(
              'Confirm & approve registered students',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pending Approval',
                          style: TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$pendingCount',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Authorized Students',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$approvedCount',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _filterQuery = v.trim()),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Filter by student name or email...',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark ? const Color(0xFF151528) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Student list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadStudents,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No registered students found.',
                              style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadStudents,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, idx) {
                                final s = filtered[idx];
                                final isConfirmed = s['isConfirmed'] == true;
                                final name = (s['fullName'] ?? s['email'] ?? 'Student').toString();
                                final email = (s['email'] ?? '').toString();
                                final id = (s['id'] ?? '').toString();

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: isDark ? const Color(0xFF141426) : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: GoogleFonts.inter(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: isDark ? Colors.white : Colors.black,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    email,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13,
                                                      color: isDark ? Colors.white60 : Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isConfirmed
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                                    : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isConfirmed
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFFF59E0B),
                                                ),
                                              ),
                                              child: Text(
                                                isConfirmed ? 'AUTHORIZED' : 'PENDING',
                                                style: TextStyle(
                                                  color: isConfirmed
                                                      ? const Color(0xFF34D399)
                                                      : const Color(0xFFFBBF24),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (!isConfirmed) ...[
                                              OutlinedButton.icon(
                                                onPressed: () => _rejectStudent(id, name),
                                                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
                                                label: const Text('Reject', style: TextStyle(color: Colors.red)),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(color: Colors.red),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton.icon(
                                                onPressed: () => _confirmStudent(id, name),
                                                icon: const Icon(Icons.check_rounded, size: 16),
                                                label: const Text('Confirm'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF10B981),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                              ),
                                            ] else ...[
                                              Row(
                                                children: [
                                                  const Icon(Icons.check_circle_rounded,
                                                      size: 16, color: Color(0xFF10B981)),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Access Approved',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF10B981),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

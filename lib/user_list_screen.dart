import 'dart:io';
import 'package:face_detection_local/database_service.dart';
import 'package:face_detection_local/models/access_log.dart';
import 'package:face_detection_local/models/user.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ==================== Users List Screen ====================
class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    final users = await DatabaseService.instance.getAllUsers();

    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  Future<void> _deleteUser(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteUser(user.id);

      // Delete photo file
      try {
        await File(user.photoPath).delete();
      } catch (_) {}

      _loadUsers();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${user.name} deleted')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registered Users')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No registered users',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadUsers,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundImage: FileImage(File(user.photoPath)),
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID: ${user.employeeId}'),
                          Text('Dept: ${user.department}'),
                          Text(
                            'Registered: ${DateFormat('dd MMM yyyy').format(user.createdAt)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteUser(user),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserDetailScreen(user: user),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ==================== User Detail Screen ====================
class UserDetailScreen extends StatelessWidget {
  final UserModel user;

  const UserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(user.photoPath),
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Details
            _DetailCard(
              icon: Icons.person,
              label: 'Full Name',
              value: user.name,
            ),
            _DetailCard(
              icon: Icons.badge,
              label: 'Employee ID',
              value: user.employeeId,
            ),
            _DetailCard(
              icon: Icons.business,
              label: 'Department',
              value: user.department,
            ),
            _DetailCard(
              icon: Icons.calendar_today,
              label: 'Registered Date',
              value: DateFormat('dd MMMM yyyy, HH:mm').format(user.createdAt),
            ),
            _DetailCard(
              icon: Icons.fingerprint,
              label: 'Face Embedding Size',
              value: '${user.faceEmbedding.length} dimensions',
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Access Logs Screen ====================
class AccessLogsScreen extends StatefulWidget {
  const AccessLogsScreen({super.key});

  @override
  State<AccessLogsScreen> createState() => _AccessLogsScreenState();
}

class _AccessLogsScreenState extends State<AccessLogsScreen> {
  List<AccessLogModel> _logs = [];
  bool _isLoading = true;
  String _filter = 'all'; // all, granted, denied

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    final logs = await DatabaseService.instance.getAccessLogs(limit: 100);

    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  List<AccessLogModel> get _filteredLogs {
    if (_filter == 'all') return _logs;
    return _logs.where((log) => log.action == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access Logs'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(
                value: 'granted',
                child: Text('Granted Only'),
              ),
              const PopupMenuItem(value: 'denied', child: Text('Denied Only')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredLogs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No access logs',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _filteredLogs.length,
                itemBuilder: (context, index) {
                  final log = _filteredLogs[index];
                  final isGranted = log.action == 'granted';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    color: isGranted
                        ? Colors.green.withValues(alpha: .05)
                        : Colors.red.withValues(alpha: .05),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isGranted ? Colors.green : Colors.red,
                        child: Icon(
                          isGranted ? Icons.check : Icons.close,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        log.userName ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGranted ? 'Access Granted' : 'Access Denied',
                            style: TextStyle(
                              color: isGranted
                                  ? Colors.green[700]
                                  : Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (log.confidenceScore != null)
                            Text(
                              'Confidence: ${(log.confidenceScore! * 100).toStringAsFixed(1)}%',
                            ),
                          Text(
                            DateFormat(
                              'dd MMM yyyy, HH:mm:ss',
                            ).format(log.timestamp),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (log.reason != null)
                            Text(
                              log.reason!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const UnchartedApp());
}

class UnchartedApp extends StatelessWidget {
  const UnchartedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uncharted Club Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const SubmissionsPage(),
    );
  }
}

class SubmissionsPage extends StatefulWidget {
  const SubmissionsPage({super.key});

  @override
  State<SubmissionsPage> createState() => _SubmissionsPageState();
}

class _SubmissionsPageState extends State<SubmissionsPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchSubmissions();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _fetchSubmissions();
    });
    await _future;
  }

  Future<List<Map<String, dynamic>>> _fetchSubmissions() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('form').get();

      final rows = snapshot.docs
          .map((doc) => {
                ...doc.data(),
                '_docId': doc.id,
              })
          .toList();

      rows.sort((a, b) {
        final aTs = a['submittedAt'];
        final bTs = b['submittedAt'];

        final aMs = aTs is Timestamp ? aTs.millisecondsSinceEpoch : 0;
        final bMs = bTs is Timestamp ? bTs.millisecondsSinceEpoch : 0;
        return bMs.compareTo(aMs);
      });

      return rows;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submissions'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final submissions = snapshot.data ?? [];
          if (submissions.isEmpty) {
            return const Center(child: Text('No submissions'));
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: submissions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = submissions[index];
                return SubmissionListCard(data: data);
              },
            ),
          );
        },
      ),
    );
  }
}

class SubmissionListCard extends StatelessWidget {
  const SubmissionListCard({super.key, required this.data});

  final Map<String, dynamic> data;

  String? _extractPhoneNumber() {
    final candidates = [data['phone'], data['whatsapp'], data['whatsApp']];
    for (final candidate in candidates) {
      final text = (candidate ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  Future<void> _openWhatsApp(BuildContext context, String phoneNumber) async {
    final normalized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      _showLaunchError(context);
      return;
    }
    final uri = Uri.parse('https://wa.me/$normalized');
    await _launch(context, uri);
  }

  Future<void> _openDialer(BuildContext context, String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    await _launch(context, uri);
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _showLaunchError(context);
    }
  }

  void _showLaunchError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the requested app.')),
    );
  }

  String _displayValue(String key) {
    final value = data[key];
    return value == null || value.toString().trim().isEmpty ? '-' : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final phone = _extractPhoneNumber();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SubmissionDetailPage(data: data),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _displayValue('fullName'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (phone != null) ...[
                    IconButton(
                      tooltip: 'WhatsApp user',
                      onPressed: () => _openWhatsApp(context, phone),
                      icon: const Icon(Icons.chat),
                    ),
                    IconButton(
                      tooltip: 'Call user',
                      onPressed: () => _openDialer(context, phone),
                      icon: const Icon(Icons.phone),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _row('Phone', phone ?? '-'),
              _row('Email', _displayValue('email')),
              _row('Type', _displayValue('type')),
              _row('Challenge', _displayValue('challenge')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class SubmissionDetailPage extends StatelessWidget {
  const SubmissionDetailPage({super.key, required this.data});

  final Map<String, dynamic> data;

  String? _extractPhoneNumber() {
    final candidates = [data['phone'], data['whatsapp'], data['whatsApp']];
    for (final candidate in candidates) {
      final text = (candidate ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  Future<void> _openWhatsApp(BuildContext context, String phoneNumber) async {
    final normalized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.isEmpty) {
      _showLaunchError(context);
      return;
    }
    final uri = Uri.parse('https://wa.me/$normalized');
    await _launch(context, uri);
  }

  Future<void> _openDialer(BuildContext context, String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    await _launch(context, uri);
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _showLaunchError(context);
    }
  }

  void _showLaunchError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the requested app.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = _extractPhoneNumber();
    final entries = data.entries.where((entry) => entry.key != '_docId').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Form Details'),
        actions: [
          if (phone != null) ...[
            IconButton(
              tooltip: 'WhatsApp user',
              onPressed: () => _openWhatsApp(context, phone),
              icon: const Icon(Icons.chat),
            ),
            IconButton(
              tooltip: 'Call user',
              onPressed: () => _openDialer(context, phone),
              icon: const Icon(Icons.phone),
            ),
          ],
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final key = _formatKey(entry.key);
          final value = entry.value == null || entry.value.toString().trim().isEmpty
              ? '-'
              : entry.value.toString();

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Text(': '),
                  Expanded(child: Text(value)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatKey(String key) {
    final withSpaces = key.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}');
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }
}

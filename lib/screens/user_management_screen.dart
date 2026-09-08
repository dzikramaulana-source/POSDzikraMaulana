import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/pos_app_bar_actions.dart';
import 'user_form_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadKasir();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    context.read<UserProvider>().loadKasir(search: query.trim());
  }

  Future<void> _deleteKasir(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kasir'),
        content: Text('Yakin ingin menghapus akun kasir "${user.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<UserProvider>().deleteKasir(user);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Kasir dihapus' : 'Gagal hapus kasir'),
        ),
      );
    }
  }

  Future<void> _sendBroadcast() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim Pengumuman'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul (opsional)',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Isi pengumuman',
                  prefixIcon: Icon(Icons.campaign),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pengumuman akan dikirim ke semua kasir.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final sent = await context.read<NotificationProvider>().broadcast(
            title: titleController.text.trim(),
            body: bodyController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: sent != null
              ? Text('Pengumuman terkirim ke $sent kasir')
              : const Text('Gagal mengirim pengumuman'),
        ),
      );
    }

    titleController.dispose();
    bodyController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Kasir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign),
            tooltip: 'Kirim Pengumuman ke Kasir',
            onPressed: _sendBroadcast,
          ),
          const PosAppBarActions(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final provider = context.read<UserProvider>();
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UserFormScreen()),
          );
          if (context.mounted) {
            provider.loadKasir();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah Kasir'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Cari nama / username kasir...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: _buildBody(userProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(UserProvider provider) {
    if (provider.isLoading && provider.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(provider.error!),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => provider.loadKasir(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (provider.users.isEmpty) {
      return const Center(
        child: Text('Belum ada kasir.\nTekan + untuk menambahkan.'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadKasir(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: provider.users.length,
        itemBuilder: (context, index) {
          final user = provider.users[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal.withValues(alpha: 0.1),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.teal),
                ),
              ),
              title: Text(user.name),
              subtitle: Text('@${user.username}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      final provider = context.read<UserProvider>();
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserFormScreen(user: user),
                        ),
                      );
                      if (context.mounted) {
                        provider.loadKasir();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteKasir(user),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

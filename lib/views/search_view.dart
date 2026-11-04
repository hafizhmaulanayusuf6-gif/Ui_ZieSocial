import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ziesocial/model/user_profile_model.dart';
import 'package:ziesocial/viewmodel/login_viewmodel.dart';
import 'package:ziesocial/viewmodel/profile_viewmodel.dart';
import 'package:ziesocial/viewmodel/search_viewmodel.dart';
import 'package:ziesocial/views/profile_view.dart';

const _primaryColor = Color(0xFF4F46E5);
const _pageColor = Color(0xFFF8F9FC);

/// Halaman pencarian akun pengguna.
///
/// Pengguna dapat mencari akun berdasarkan username atau nama,
/// lalu mengetuk hasil untuk membuka profil pengguna tersebut.
class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _controller = TextEditingController();
  int _currentUserId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _currentUserId =
          int.tryParse(context.read<LoginViewModel>().user?.id ?? '') ?? 0;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    // Bersihkan state pencarian saat halaman ditutup
    context.read<SearchViewModel>().clearSearch();
    super.dispose();
  }

  void _navigateToProfile(UserSummaryModel user) {
    // Reset profil yang mungkin masih tersisa dari navigasi sebelumnya
    context.read<ProfileViewModel>().resetProfile();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProfileView(profileUserId: user.id, username: user.username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1F2937),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Cari Pengguna',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search Bar ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari username atau nama...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF9CA3AF),
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (_, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF9CA3AF),
                        size: 20,
                      ),
                      onPressed: () {
                        _controller.clear();
                        context.read<SearchViewModel>().onKeywordChanged(
                          '',
                          viewerId: _currentUserId,
                        );
                      },
                    );
                  },
                ),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: _primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (value) {
                context.read<SearchViewModel>().onKeywordChanged(
                  value,
                  viewerId: _currentUserId,
                );
              },
            ),
          ),

          // ── Konten hasil pencarian ────────────────────────────────────
          Expanded(
            child: Consumer<SearchViewModel>(
              builder: (context, vm, _) {
                // Belum ada keyword
                if (vm.currentKeyword.isEmpty) {
                  return _buildIdleState();
                }

                // Loading
                if (vm.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  );
                }

                // Error
                if (vm.errorMessage != null) {
                  return _buildErrorState(vm.errorMessage!);
                }

                // Tidak ada hasil
                if (vm.results.isEmpty) {
                  return _buildEmptyState(vm.currentKeyword);
                }

                // Daftar hasil
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: vm.results.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 16,
                    color: Color(0xFFF3F4F6),
                  ),
                  itemBuilder: (context, index) {
                    final user = vm.results[index];
                    return _UserResultTile(
                      user: user,
                      onTap: () => _navigateToProfile(user),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Idle state (sebelum mengetik) ─────────────────────────────────────
  Widget _buildIdleState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_rounded,
              size: 48,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Temukan Pengguna',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ketik username atau nama\nuntuk mencari pengguna.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────
  Widget _buildEmptyState(String keyword) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 52,
              color: Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pengguna tidak ditemukan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tidak ada pengguna yang cocok\ndengan "$keyword".',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────
  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Pencarian gagal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                context.read<SearchViewModel>().onKeywordChanged(
                  _controller.text,
                  viewerId: _currentUserId,
                );
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Tile satu baris hasil pencarian: avatar, nama, dan username.
// ─────────────────────────────────────────────────────────────────────────────
class _UserResultTile extends StatelessWidget {
  final UserSummaryModel user;
  final VoidCallback onTap;

  const _UserResultTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar dengan fallback ikon person
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE9EDF5),
              backgroundImage: user.avatarUrl.isNotEmpty
                  ? NetworkImage(user.avatarUrl)
                  : null,
              child: user.avatarUrl.isEmpty
                  ? const Icon(
                      Icons.person_rounded,
                      size: 26,
                      color: Color(0xFF9CA3AF),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Nama dan username
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name.isNotEmpty ? user.name : user.username,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD1D5DB),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

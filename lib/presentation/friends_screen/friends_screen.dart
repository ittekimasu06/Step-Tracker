import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/friend_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_circle.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  static const _minQueryLength = 3;

  // 0 = Connect, 1 = Leaderboard, 2 = Friends - Friends stays the default
  // landing view, matching this screen's pre-redesign default.
  int _selectedTab = 2;

  bool _loadingFriends = true;
  List<Map<String, dynamic>> _friends = [];

  String _leaderboardPeriod = 'day';
  bool _loadingLeaderboard = true;
  List<Map<String, dynamic>> _leaderboard = [];

  final _searchController = TextEditingController();
  List<Map<String, dynamic>>? _searchResults;
  bool _searching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() => _loadingFriends = true);
    try {
      final friends = await FriendService.instance.getFriends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _loadingFriends = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingFriends = false);
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _loadingLeaderboard = true);
    try {
      final entries = await FriendService.instance.getLeaderboard(_leaderboardPeriod);
      if (!mounted) return;
      setState(() {
        _leaderboard = entries;
        _loadingLeaderboard = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingLeaderboard = false);
    }
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().length < _minQueryLength) {
      setState(() {
        _searchResults = null;
        _searching = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await FriendService.instance.search(query.trim());
      if (!mounted || _searchController.text.trim() != query.trim()) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = e.message;
      });
    }
  }

  Future<void> _sendRequest(String userId) async {
    try {
      await FriendService.instance.sendRequest(userId);
      await _onSearchChanged(_searchController.text);
      await _loadFriends();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_loadFriends(), _loadLeaderboard()]);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => context.go(AppRoutes.activityDashboardScreen),
            ),
            Text(
              'Friends',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.person_add_alt_outlined, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => context.push(AppRoutes.friendRequestsScreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchField(),
        if (_searchController.text.trim().length >= _minQueryLength) ...[
          const SizedBox(height: 16),
          _buildSearchResults(),
        ] else ...[
          const SizedBox(height: 16),
          _buildTabRow(),
          const SizedBox(height: 16),
          switch (_selectedTab) {
            0 => _buildConnectTab(),
            1 => _buildLeaderboardTab(),
            _ => _buildFriendsList(),
          },
        ],
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: 'Search people by name',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.overlay(context, 20)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.overlay(context, 20)),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchError != null) {
      return Text(
        _searchError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error, fontFamily: 'Manrope'),
      );
    }
    final results = _searchResults ?? const [];
    if (results.isEmpty) {
      return Text(
        'No one found with that name.',
        style: TextStyle(color: AppTheme.textSecondary(context), fontFamily: 'Manrope'),
      );
    }
    return Column(
      children: results.map((r) => _buildSearchResultRow(r)).toList(),
    );
  }

  Widget _buildSearchResultRow(Map<String, dynamic> result) {
    final status = result['status'] as String;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.overlay(context, 15), width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              result['fullName'] as String? ?? 'Unknown user',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          _buildStatusAction(status, result['userId'] as String),
        ],
      ),
    );
  }

  Widget _buildStatusAction(String status, String userId) {
    switch (status) {
      case 'FRIENDS':
        return _pill('Friends', AppTheme.textSecondary(context));
      case 'PENDING_SENT':
        return _pill('Requested', AppTheme.textSecondary(context));
      case 'PENDING_RECEIVED':
        return _pill('Check Requests', AppTheme.stepsGreen);
      default:
        return TextButton(
          onPressed: () => _sendRequest(userId),
          child: const Text('Add', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600)),
        );
    }
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Manrope', fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  /// Plain text labels with a bottom-border underline on the selected tab -
  /// per the mockup, not the filled pill-button style used for the
  /// day/week/month sub-toggle inside the Leaderboard tab or the
  /// Sent/Received toggle on the Requests screen.
  Widget _buildTabRow() {
    return Row(
      children: [
        Expanded(child: _textTab('Connect', 0)),
        Expanded(child: _textTab('Leaderboard', 1)),
        Expanded(child: _textTab('Friends', 2)),
      ],
    );
  }

  Widget _textTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = index);
        // Refetch every time Leaderboard is opened (including re-tapping it
        // while already selected) rather than relying on whatever was cached
        // from the last fetch - friends' step counts change continuously
        // throughout the day, so a stale ranking is the norm, not the
        // exception, without this.
        if (index == 1) _loadLeaderboard();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.stepsGreen : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.stepsGreen : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'Coming soon.',
          style: TextStyle(color: AppTheme.textSecondary(context), fontFamily: 'Manrope'),
        ),
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPeriodToggle(),
        const SizedBox(height: 16),
        if (_loadingLeaderboard)
          const Center(child: CircularProgressIndicator())
        else if (_leaderboard.isEmpty)
          Text(
            'Add friends to see a leaderboard.',
            style: TextStyle(color: AppTheme.textSecondary(context), fontFamily: 'Manrope'),
          )
        else
          Column(
            children: List.generate(_leaderboard.length, (i) => _buildLeaderboardRow(_leaderboard[i], i + 1)),
          ),
      ],
    );
  }

  Widget _buildPeriodToggle() {
    return Row(
      children: [
        Expanded(child: _periodButton('Day', 'day')),
        const SizedBox(width: 8),
        Expanded(child: _periodButton('Week', 'week')),
        const SizedBox(width: 8),
        Expanded(child: _periodButton('Month', 'month')),
      ],
    );
  }

  Widget _periodButton(String label, String period) {
    final isSelected = _leaderboardPeriod == period;
    return GestureDetector(
      onTap: () {
        if (_leaderboardPeriod == period) return;
        setState(() => _leaderboardPeriod = period);
        _loadLeaderboard();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.stepsGreen.withAlpha(38) : AppTheme.overlay(context, 10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.stepsGreen.withAlpha(128) : AppTheme.overlay(context, 20),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.stepsGreen : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardRow(Map<String, dynamic> entry, int rank) {
    final isSelf = entry['isSelf'] as bool? ?? false;
    final steps = entry['steps'] as int? ?? 0;
    final name = isSelf ? 'You' : (entry['fullName'] as String? ?? 'Unknown user');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isSelf
            ? AppTheme.stepsGreen.withAlpha(20)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelf ? AppTheme.stepsGreen.withAlpha(80) : AppTheme.overlay(context, 15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AvatarCircle(
            avatarId: entry['avatarId'] as String?,
            displayName: entry['fullName'] as String? ?? 'Unknown user',
            size: 32,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            '$steps steps',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.stepsGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_loadingFriends) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_friends.isEmpty) {
      return Text(
        'No friends yet - search above to add someone.',
        style: TextStyle(color: AppTheme.textSecondary(context), fontFamily: 'Manrope'),
      );
    }
    return Column(children: _friends.map(_buildFriendRow).toList());
  }

  Widget _buildFriendRow(Map<String, dynamic> friend) {
    final steps = friend['todaySteps'] as int? ?? 0;
    final activeMin = friend['todayActiveMinutes'] as int? ?? 0;
    final fullName = friend['fullName'] as String? ?? 'Unknown user';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.overlay(context, 15), width: 1),
      ),
      child: Row(
        children: [
          AvatarCircle(
            avatarId: friend['avatarId'] as String?,
            displayName: fullName,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fullName,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$steps steps',
                style: const TextStyle(fontFamily: 'Manrope', fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.stepsGreen),
              ),
              const SizedBox(height: 2),
              Text(
                '$activeMin min active',
                style: TextStyle(fontFamily: 'Manrope', fontSize: 11, color: AppTheme.textSecondary(context)),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.person_remove_outlined, size: 18, color: AppTheme.textSecondary(context)),
            onPressed: () => _confirmUnfriend(friend['friendUserId'] as String, friend['fullName'] as String? ?? 'this person'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUnfriend(String friendUserId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove Friend?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'You and $name will no longer see each other\'s progress.',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: AppTheme.textSecondary(ctx),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: Theme.of(ctx).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FriendService.instance.unfriend(friendUserId);
      await _loadFriends();
      await _loadLeaderboard();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/friend_service.dart';
import '../../services/post_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_circle.dart';
import 'widgets/friend_status_action.dart';
import 'widgets/post_card_widget.dart';
import 'widgets/user_profile_preview_sheet.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with WidgetsBindingObserver {
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
  final _searchFocusNode = FocusNode();
  List<Map<String, dynamic>>? _searchResults;
  bool _searching = false;
  String? _searchError;

  // Tracks the keyboard's last-known open/closed state (inferred from
  // viewInsets.bottom - see didChangeMetrics) so the search field's focus
  // can be dropped the moment the keyboard closes by any means other than
  // tapping outside it (system back button, swipe-down-to-dismiss) - Flutter
  // doesn't close a TextField's logical focus just because the on-screen
  // keyboard hid, so without this the field is left showing its focused
  // (blue-bordered, blinking-cursor) state with no keyboard visible.
  bool _keyboardWasVisible = false;

  bool _loadingDiscover = true;
  List<Map<String, dynamic>> _discoverUsers = [];

  bool _loadingFeed = true;
  List<Map<String, dynamic>> _feedPosts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFriends();
    _loadLeaderboard();
    _loadDiscover();
    _loadFeed();
  }

  /// Fires on every screen-metrics change, including the keyboard opening/
  /// closing (it resizes the view) - see [_keyboardWasVisible]'s doc for why
  /// this is the only reliable way to notice a keyboard dismissed by means
  /// other than tapping outside the field.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final keyboardVisible = view.viewInsets.bottom > 0;
    if (_keyboardWasVisible && !keyboardVisible && _searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
    _keyboardWasVisible = keyboardVisible;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchFocusNode.dispose();
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

  Future<void> _loadDiscover() async {
    setState(() => _loadingDiscover = true);
    try {
      final users = await FriendService.instance.discover();
      if (!mounted) return;
      setState(() {
        _discoverUsers = users;
        _loadingDiscover = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingDiscover = false);
    }
  }

  Future<void> _loadFeed() async {
    setState(() => _loadingFeed = true);
    try {
      final posts = await PostService.instance.getFeed();
      if (!mounted) return;
      setState(() {
        _feedPosts = posts;
        _loadingFeed = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingFeed = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final postId = post['id'] as String;
    final likedByMe = post['likedByMe'] as bool? ?? false;
    // Optimistic update - a like/unlike should feel instant, and a failure is rare/low-stakes
    // enough to just revert via a full reload rather than tracking a pending-undo state.
    setState(() {
      post['likedByMe'] = !likedByMe;
      post['likeCount'] = (post['likeCount'] as int? ?? 0) + (likedByMe ? -1 : 1);
    });
    try {
      if (likedByMe) {
        await PostService.instance.unlikePost(postId);
      } else {
        await PostService.instance.likePost(postId);
      }
    } on ApiException {
      if (!mounted) return;
      await _loadFeed();
    }
  }

  Future<void> _sendRequestFromDiscover(String userId) async {
    try {
      await FriendService.instance.sendRequest(userId);
      await Future.wait([_loadDiscover(), _loadFriends()]);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
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
      body: GestureDetector(
        // Tapping anywhere that isn't the search field itself (or another
        // focusable control) dismisses the keyboard and drops the field's
        // focus - translucent so it doesn't swallow taps meant for buttons/
        // list rows underneath, it just also runs this before them.
        behavior: HitTestBehavior.translucent,
        onTap: () => _searchFocusNode.unfocus(),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([_loadFriends(), _loadLeaderboard(), _loadDiscover(), _loadFeed()]);
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
      focusNode: _searchFocusNode,
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
    final fullName = result['fullName'] as String? ?? 'Unknown user';
    final userId = result['userId'] as String;
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
          AvatarCircle(avatarId: result['avatarId'] as String?, displayName: fullName, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fullName,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          FriendStatusAction(status: status, onSendRequest: () => _sendRequest(userId)),
        ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Connect with other people'),
        const SizedBox(height: 12),
        _buildDiscoverRow(),
        const SizedBox(height: 24),
        _buildSectionTitle('See what your friends have shared'),
        const SizedBox(height: 12),
        _buildFeedList(),
      ],
    );
  }

  Widget _buildSectionTitle(String label) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildDiscoverRow() {
    if (_loadingDiscover) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_discoverUsers.isEmpty) {
      return Text(
        'No one else here yet.',
        style: TextStyle(color: AppTheme.textSecondary(context), fontFamily: 'Manrope'),
      );
    }
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _discoverUsers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) => _buildDiscoverAvatar(_discoverUsers[i]),
      ),
    );
  }

  Widget _buildDiscoverAvatar(Map<String, dynamic> user) {
    final fullName = user['fullName'] as String? ?? 'Unknown user';
    final userId = user['userId'] as String;
    return GestureDetector(
      onTap: () => UserProfilePreviewSheet.show(
        context,
        user: user,
        onSendRequest: () => _sendRequestFromDiscover(userId),
      ),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            AvatarCircle(avatarId: user['avatarId'] as String?, displayName: fullName, size: 56),
            const SizedBox(height: 6),
            Text(
              fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedList() {
    if (_loadingFeed) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_feedPosts.isEmpty) {
      return Text(
        'Nothing shared yet - add friends to see their progress here.',
        style: TextStyle(color: AppTheme.textSecondary(context), fontFamily: 'Manrope'),
      );
    }
    return Column(
      children: _feedPosts
          .map((post) => PostCardWidget(post: post, onToggleLike: () => _toggleLike(post)))
          .toList(),
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

import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/friend_service.dart';
import '../../theme/app_theme.dart';

/// A real pushed screen (not a bottom-nav tab) - has a genuine back button.
/// Splits what used to be [FriendsScreen]'s single inline "Requests" tab
/// (received only) into Sent/Received sub-tabs.
class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  int _selectedTab = 0; // 0 = Received, 1 = Sent
  bool _loadingReceived = true;
  bool _loadingSent = true;
  List<Map<String, dynamic>> _received = [];
  List<Map<String, dynamic>> _sent = [];

  @override
  void initState() {
    super.initState();
    _loadReceived();
    _loadSent();
  }

  Future<void> _loadReceived() async {
    setState(() => _loadingReceived = true);
    try {
      final requests = await FriendService.instance.getIncomingRequests();
      if (!mounted) return;
      setState(() {
        _received = requests;
        _loadingReceived = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingReceived = false);
    }
  }

  Future<void> _loadSent() async {
    setState(() => _loadingSent = true);
    try {
      final requests = await FriendService.instance.getSentRequests();
      if (!mounted) return;
      setState(() {
        _sent = requests;
        _loadingSent = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loadingSent = false);
    }
  }

  Future<void> _accept(String requestId) async {
    try {
      await FriendService.instance.acceptRequest(requestId);
      await _loadReceived();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _decline(String requestId) async {
    try {
      await FriendService.instance.declineRequest(requestId);
      await _loadReceived();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _cancel(String requestId) async {
    try {
      await FriendService.instance.cancelRequest(requestId);
      await _loadSent();
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
            await Future.wait([_loadReceived(), _loadSent()]);
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
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Text(
              'Requests',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
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
        _buildTabToggle(),
        const SizedBox(height: 16),
        _selectedTab == 0 ? _buildReceivedList() : _buildSentList(),
      ],
    );
  }

  Widget _buildTabToggle() {
    return Row(
      children: [
        Expanded(child: _tabButton('Received${_received.isNotEmpty ? ' (${_received.length})' : ''}', 0)),
        const SizedBox(width: 8),
        Expanded(child: _tabButton('Sent', 1)),
      ],
    );
  }

  Widget _tabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
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
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppTheme.stepsGreen : AppTheme.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _buildReceivedList() {
    if (_loadingReceived) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_received.isEmpty) {
      return Text(
        'No pending friend requests.',
        style: TextStyle(color: AppTheme.textSecondary(context), fontFamily: 'Manrope'),
      );
    }
    return Column(children: _received.map(_buildReceivedRow).toList());
  }

  Widget _buildReceivedRow(Map<String, dynamic> request) {
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
          Expanded(
            child: Text(
              request['fromFullName'] as String? ?? 'Unknown user',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _decline(request['id'] as String),
            child: Text('Decline', style: TextStyle(color: AppTheme.textSecondary(context), fontFamily: 'Manrope')),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => _accept(request['id'] as String),
            child: const Text('Accept', style: TextStyle(color: AppTheme.stepsGreen, fontFamily: 'Manrope', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSentList() {
    if (_loadingSent) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sent.isEmpty) {
      return Text(
        'No friend requests sent.',
        style: TextStyle(color: AppTheme.textSecondary(context), fontFamily: 'Manrope'),
      );
    }
    return Column(children: _sent.map(_buildSentRow).toList());
  }

  Widget _buildSentRow(Map<String, dynamic> request) {
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
          Expanded(
            child: Text(
              request['toFullName'] as String? ?? 'Unknown user',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _cancel(request['id'] as String),
            child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.error, fontFamily: 'Manrope')),
          ),
        ],
      ),
    );
  }
}

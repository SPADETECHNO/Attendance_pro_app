import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:attendance_pro_app/services/auth_service.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/screens/users/session_details_screen.dart';
import 'package:attendance_pro_app/screens/auth/splash_screen.dart';
import 'package:attendance_pro_app/widgets/loading_widget.dart';
import 'package:attendance_pro_app/widgets/custom_button.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/models/user_model.dart';
import 'package:attendance_pro_app/models/session_model.dart';
import 'dart:convert';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  UserModel? _currentUser;
  List<SessionModel> _upcomingSessions = [];
  List<SessionModel> _liveSessions = [];
  List<SessionModel> _recentSessions = [];
  
  bool _isLoading = true;
  bool _isQrScannerActive = false;
  MobileScannerController? _scannerController;
  
  int _totalSessions = 0;
  int _attendedSessions = 0;
  double _attendancePercentage = 0.0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      final authService = context.read<AuthService>();
      final databaseService = context.read<DatabaseService>();

      // Get current user
      final user = await authService.getCurrentUserProfile();
      if (user == null) {
        _navigateToLogin();
        return;
      }

      // Get user's sessions
      final allSessions = await databaseService.getUserSessions(user.id);
      
      final liveSessions = allSessions.where((s) => s.isLive).toList();
      final upcomingSessions = allSessions
          .where((s) => s.isUpcoming)
          .take(5)
          .toList();
      final recentSessions = allSessions
          .where((s) => s.hasEnded)
          .take(5)
          .toList();

      // Calculate attendance statistics
      final totalSessions = allSessions.where((s) => s.hasEnded).length;
      // TODO: Get actual attendance records to calculate attended sessions
      final attendedSessions = (totalSessions * 0.8).round(); // Mock 80% attendance
      final attendancePercentage = totalSessions > 0 
          ? (attendedSessions / totalSessions) * 100 
          : 0.0;

      setState(() {
        _currentUser = user;
        _liveSessions = liveSessions;
        _upcomingSessions = upcomingSessions;
        _recentSessions = recentSessions;
        _totalSessions = totalSessions;
        _attendedSessions = attendedSessions;
        _attendancePercentage = attendancePercentage;
        _isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('Load user dashboard error: $e');
      AppHelpers.showErrorToast('Failed to load dashboard');
      setState(() => _isLoading = false);
    }
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SplashScreen()),
    );
  }

  Future<void> _logout() async {
    try {
      final authService = context.read<AuthService>();
      await authService.signOut();
      _navigateToLogin();
    } catch (e) {
      AppHelpers.showErrorToast('Logout failed');
    }
  }

  void _startQrScanner() {
    setState(() {
      _isQrScannerActive = true;
      _scannerController = MobileScannerController();
    });
  }

  void _stopQrScanner() {
    setState(() {
      _isQrScannerActive = false;
    });
    _scannerController?.dispose();
    _scannerController = null;
  }

  Future<void> _onQRScanned(BarcodeCapture capture) async {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null) return;

    try {
      // Parse QR code data
      final qrData = jsonDecode(code);
      final sessionId = qrData['session_id'] as String?;
      
      if (sessionId == null) {
        AppHelpers.showErrorToast('Invalid QR code');
        return;
      }

      // Stop scanner and navigate to session
      _stopQrScanner();
      
      // Find the session
      final session = _liveSessions.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => throw Exception('Session not found or not active'),
      );

      // Navigate to session detail for attendance marking
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailScreen(session: session),
        ),
      ).then((_) => _loadDashboardData());

    } catch (e) {
      AppHelpers.showErrorToast('Invalid QR code or session not available');
      _stopQrScanner();
    }
  }

  void _navigateToSessionDetail(SessionModel session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(session: session),
      ),
    ).then((_) => _loadDashboardData());
  }

  void _showUserProfile() {
    showDialog(
      context: context,
      builder: (context) => UserProfileDialog(
        user: _currentUser!,
        onUpdated: _loadDashboardData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: LoadingWidget(message: 'Loading dashboard...'),
      );
    }

    if (_isQrScannerActive) {
      return _buildQrScannerView(theme);
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.onPrimary.withAlpha((0.2 * 255).toInt()),
              child: Text(
                _currentUser?.initials ?? '?',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, ${_currentUser?.name?.split(' ').first ?? 'Student'}!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    // ✅ Fixed: Removed null-aware operator where receiver can't be null
                    'ID: ${_currentUser!.userId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimary.withAlpha((0.8 * 255).toInt()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.user,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_liveSessions.isNotEmpty)
            IconButton(
              onPressed: _startQrScanner,
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan QR Code',
            ),
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'profile',
                child: const ListTile(
                  leading: Icon(Icons.person),
                  title: Text('My Profile'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: const ListTile(
                  leading: Icon(Icons.logout, color: AppColors.error),
                  title: Text('Logout'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _showUserProfile();
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attendance Statistics
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.user,
                      AppColors.user.withAlpha((0.8 * 255).toInt()),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSizes.md),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.2 * 255).toInt()),
                            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                          ),
                          child: const Icon(
                            Icons.school,
                            color: Colors.white,
                            size: AppSizes.iconLg,
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Attendance Overview',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Your current attendance status',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withAlpha((0.8 * 255).toInt()),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Sessions',
                            '$_totalSessions',
                            Icons.event,
                            Colors.white.withAlpha((0.9 * 255).toInt()),
                            theme,
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: _buildStatCard(
                            'Attended',
                            '$_attendedSessions',
                            Icons.check_circle,
                            Colors.white.withAlpha((0.9 * 255).toInt()),
                            theme,
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: _buildStatCard(
                            'Percentage',
                            '${_attendancePercentage.toStringAsFixed(1)}%',
                            Icons.percent,
                            Colors.white.withAlpha((0.9 * 255).toInt()),
                            theme,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.xl),

              // Live Sessions
              if (_liveSessions.isNotEmpty) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.xs),
                      decoration: BoxDecoration(
                        color: AppColors.live.withAlpha((0.1 * 255).toInt()),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: Icon(
                        Icons.live_tv,
                        color: AppColors.live,
                        size: AppSizes.iconSm,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Text(
                      'Live Sessions',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.sm,
                        vertical: AppSizes.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.live,
                        borderRadius: BorderRadius.circular(AppSizes.radiusRound),
                      ),
                      child: Text(
                        '${_liveSessions.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _liveSessions.length,
                  itemBuilder: (context, index) {
                    final session = _liveSessions[index];
                    return _buildLiveSessionCard(session, theme);
                  },
                ),
                const SizedBox(height: AppSizes.xl),
              ],

              // Quick Actions
              if (_liveSessions.isNotEmpty) ...[
                Text(
                  'Quick Actions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                CustomButton(
                  text: 'Scan QR Code to Mark Attendance',
                  onPressed: _startQrScanner,
                  icon: Icons.qr_code_scanner,
                  backgroundColor: AppColors.success,
                ),
                const SizedBox(height: AppSizes.xl),
              ],

              // Upcoming Sessions
              if (_upcomingSessions.isNotEmpty) ...[
                Text(
                  'Upcoming Sessions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _upcomingSessions.length,
                  itemBuilder: (context, index) {
                    final session = _upcomingSessions[index];
                    return _buildUpcomingSessionCard(session, theme);
                  },
                ),
                const SizedBox(height: AppSizes.xl),
              ],

              // Recent Sessions
              if (_recentSessions.isNotEmpty) ...[
                Text(
                  'Recent Sessions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentSessions.length,
                  itemBuilder: (context, index) {
                    final session = _recentSessions[index];
                    return _buildRecentSessionCard(session, theme);
                  },
                ),
              ],

              // Empty State
              if (_liveSessions.isEmpty && _upcomingSessions.isEmpty && _recentSessions.isEmpty)
                const EmptyStateWidget(
                  icon: Icons.event_note,
                  title: 'No Sessions Available',
                  subtitle: 'Check back later for upcoming sessions',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrScannerView(ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: AppColors.user,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: _stopQrScanner,
          icon: const Icon(Icons.close),
        ),
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.md),
            color: AppColors.info.withAlpha((0.1 * 255).toInt()),
            child: Column(
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  color: AppColors.info,
                  size: AppSizes.iconLg,
                ),
                const SizedBox(height: AppSizes.sm),
                Text(
                  'Point your camera at the QR code',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Make sure you\'re within the allowed location',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.info,
                  ),
                ),
              ],
            ),
          ),

          // Scanner
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onQRScanned,
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.user,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    ),
                    child: Stack(
                      children: [
                        // Corner indicators
                        Positioned(
                          top: -1,
                          left: -1,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppColors.user, width: 5),
                                left: BorderSide(color: AppColors.user, width: 5),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: AppColors.user, width: 5),
                                right: BorderSide(color: AppColors.user, width: 5),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -1,
                          left: -1,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.user, width: 5),
                                left: BorderSide(color: AppColors.user, width: 5),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -1,
                          right: -1,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.user, width: 5),
                                right: BorderSide(color: AppColors.user, width: 5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Live Sessions Info
          if (_liveSessions.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.md),
              // ✅ Fixed: Using surfaceContainerHighest instead of deprecated surfaceVariant
              color: theme.colorScheme.surfaceContainerHighest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Live Sessions:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  ...(_liveSessions.map((session) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.xs),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.live,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            '${session.name} • ${AppHelpers.formatTime(session.endDateTime)} remaining',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color textColor,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.1 * 255).toInt()),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: textColor,
            size: AppSizes.iconMd,
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: textColor.withAlpha((0.8 * 255).toInt()),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSessionCard(SessionModel session, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      color: AppColors.live.withAlpha((0.05 * 255).toInt()),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSizes.sm),
          decoration: BoxDecoration(
            color: AppColors.live.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: const Icon(
            Icons.live_tv,
            color: AppColors.live,
          ),
        ),
        title: Text(
          session.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ends at ${AppHelpers.formatTime(session.endDateTime)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSizes.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.live,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                '● LIVE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, color: AppColors.live),
            Text(
              'Tap to Join',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.live,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        onTap: () => _navigateToSessionDetail(session),
      ),
    );
  }

  Widget _buildUpcomingSessionCard(SessionModel session, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSizes.sm),
          decoration: BoxDecoration(
            color: AppColors.info.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: const Icon(
            Icons.schedule,
            color: AppColors.info,
          ),
        ),
        title: Text(
          session.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppHelpers.formatDateTime(session.startDateTime),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              session.timeRemaining,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.info,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToSessionDetail(session),
      ),
    );
  }

  Widget _buildRecentSessionCard(SessionModel session, ThemeData theme) {
    // TODO: Get actual attendance status from database
    final isAttended = true; // Mock attendance status

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppSizes.sm),
          decoration: BoxDecoration(
            color: isAttended 
                ? AppColors.success.withAlpha((0.1 * 255).toInt())
                : AppColors.error.withAlpha((0.1 * 255).toInt()),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Icon(
            isAttended ? Icons.check_circle : Icons.cancel,
            color: isAttended ? AppColors.success : AppColors.error,
          ),
        ),
        title: Text(
          session.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppHelpers.formatDateTime(session.startDateTime),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSizes.xs),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.xs,
              ),
              decoration: BoxDecoration(
                color: isAttended 
                    ? AppColors.success.withAlpha((0.1 * 255).toInt())
                    : AppColors.error.withAlpha((0.1 * 255).toInt()),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Text(
                isAttended ? 'PRESENT' : 'ABSENT',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isAttended ? AppColors.success : AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToSessionDetail(session),
      ),
    );
  }
}

// User Profile Dialog
class UserProfileDialog extends StatelessWidget {
  final UserModel user;
  final VoidCallback onUpdated;

  const UserProfileDialog({
    super.key,
    required this.user,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.user.withAlpha((0.1 * 255).toInt()),
            child: Text(
              user.initials,
              style: const TextStyle(
                color: AppColors.user,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              'My Profile',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileRow('Name', user.name, Icons.person),
            _buildProfileRow('User ID', user.userId, Icons.badge),
            _buildProfileRow('Email', user.email, Icons.email),
            if (user.phone?.isNotEmpty == true)
              _buildProfileRow('Phone', user.phone!, Icons.phone),
            _buildProfileRow('Role', user.roleDisplayName, Icons.admin_panel_settings),
            _buildProfileRow(
              'Account Status',
              user.isActive ? 'Active' : 'Inactive',
              Icons.account_circle,
              statusColor: user.isActive ? AppColors.success : AppColors.error,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            AppHelpers.showInfoToast('Profile editing feature coming soon');
          },
          child: const Text('Edit Profile'),
        ),
      ],
    );
  }

  Widget _buildProfileRow(
    String label,
    String value,
    IconData icon, {
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: AppSizes.iconSm,
            color: statusColor ?? AppColors.user,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.gray600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

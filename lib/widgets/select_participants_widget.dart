// lib/widgets/select_participants_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:attendance_pro_app/services/database_service.dart';
import 'package:attendance_pro_app/services/csv_service.dart';
import 'package:attendance_pro_app/widgets/custom_text_field.dart';
import 'package:attendance_pro_app/utils/constants.dart';
import 'package:attendance_pro_app/utils/helpers.dart';
import 'package:attendance_pro_app/constants/app_constants.dart';
import 'package:csv/csv.dart';

class SelectParticipantsWidget extends StatefulWidget {
  final String instituteId;
  final String? departmentId;
  final String? academicYearId;
  final List<String> initialSelectedUserIds;
  final Function(List<Map<String, dynamic>>) onSelectionChanged;

  const SelectParticipantsWidget({
    super.key,
    required this.instituteId,
    this.departmentId,
    this.academicYearId,
    this.initialSelectedUserIds = const [],
    required this.onSelectionChanged,
  });

  @override
  State<SelectParticipantsWidget> createState() => _SelectParticipantsWidgetState();
}

class _SelectParticipantsWidgetState extends State<SelectParticipantsWidget> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  Set<String> selectedUserIds = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    selectedUserIds = Set.from(widget.initialSelectedUserIds);
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => isLoading = true);
    try {
      final databaseService = context.read<DatabaseService>();
      AppHelpers.debugLog('🔍 Loading master list for institute: ${widget.instituteId}');
      final response = await databaseService.client
          .from(AppConstants.instituteMasterListTable)
          .select('''
            id,
            user_id,
            name,
            email,
            phone,
            account_status,
            department_id,
            academic_year_id,
            departments(id, name),
            academic_years(id, year_label)
          ''')
          .eq('institute_id', widget.instituteId)
          .eq('account_status', 'active')
          .order('name', ascending: true);

      AppHelpers.debugLog('✅ Master list loaded: ${response.length} users');
      
      if (response.isNotEmpty) {
        AppHelpers.debugLog('Sample user: ${response.first['name']} (${response.first['user_id']})');
      } else {
        AppHelpers.debugLog('⚠️ NO USERS FOUND!');
      }

      setState(() {
        allUsers = List<Map<String, dynamic>>.from(response);
        filteredUsers = allUsers;
        isLoading = false;
      });
    } catch (e) {
      AppHelpers.debugError('❌ Load users error: $e');
      if (mounted) {
        AppHelpers.showErrorToast('Failed to load users: ${e.toString()}');
        setState(() => isLoading = false);
      }
    }
  }

  // Future<void> _loadUsers() async {
  //   setState(() => isLoading = true);
  //   try {
  //     final databaseService = context.read<DatabaseService>();

  //     // ⭐ Build query step by step
  //     var query = databaseService.client
  //         .from(AppConstants.instituteMasterListTable)
  //         .select('''
  //         id,
  //         user_id,
  //         name,
  //         email,
  //         phone,
  //         account_status,
  //         department_id,
  //         academic_year_id,
  //         departments(id, name),
  //         academic_years(id, year_label)
  //       ''')
  //         .eq('institute_id', widget.instituteId)
  //         .eq('account_status', 'active');

  //     // ⭐ Apply filters conditionally
  //     if (widget.departmentId != null) {
  //       query = query.eq('department_id', widget.departmentId!);
  //     }

  //     if (widget.academicYearId != null) {
  //       query = query.eq('academic_year_id', widget.academicYearId!);
  //     }

  //     final response = await query.order('name', ascending: true);

  //     setState(() {
  //       allUsers = List<Map<String, dynamic>>.from(response);
  //       filteredUsers = allUsers;
  //       isLoading = false;
  //     });
  //   } catch (e) {
  //     AppHelpers.showErrorToast('Failed to load users: ${e.toString()}');
  //     setState(() => isLoading = false);
  //   }
  // }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredUsers = allUsers.where((user) {
        final matchesSearch = query.isEmpty ||
            user['name'].toString().toLowerCase().contains(query) ||
            user['user_id'].toString().toLowerCase().contains(query) ||
            user['email'].toString().toLowerCase().contains(query);
        
        final matchesDepartment = widget.departmentId == null ||
            user['department_id'] == widget.departmentId;
        
        final matchesYear = widget.academicYearId == null ||
            user['academic_year_id'] == widget.academicYearId;
        
        return matchesSearch && matchesDepartment && matchesYear;
      }).toList();
    });
  }

  void _selectAll() {
    setState(() {
      for (var user in filteredUsers) {
        selectedUserIds.add(user['id']);
      }
    });
    _notifySelection();
  }

  void _deselectAll() {
    setState(() {
      for (var user in filteredUsers) {
        selectedUserIds.remove(user['id']);
      }
    });
    _notifySelection();
  }

  void _toggleUser(String userId) {
    setState(() {
      if (selectedUserIds.contains(userId)) {
        selectedUserIds.remove(userId);
      } else {
        selectedUserIds.add(userId);
      }
    });
    _notifySelection();
  }

  void _notifySelection() {
    final selected = allUsers.where((user) => selectedUserIds.contains(user['id'])).toList();
    widget.onSelectionChanged(selected);
  }

  Future<void> _uploadCsv() async {
    try {
      final file = await CsvService.pickCsvFile();
      if (file == null) return;

      final List<List<dynamic>> csvRows = const CsvToListConverter().convert(
        file.content,
        eol: '\n',
        fieldDelimiter: ',',
      );

      final List<String> csvUserIds = [];
      for (var row in csvRows.skip(1)) {
        if (row.isNotEmpty) {
          csvUserIds.add(row[0].toString().trim());
        }
      }

      int validCount = 0;
      int invalidCount = 0;
      
      for (var userId in csvUserIds) {
        final user = allUsers.firstWhere(
          (u) => u['user_id'] == userId,
          orElse: () => {},
        );
        if (user.isNotEmpty) {
          selectedUserIds.add(user['id']);
          validCount++;
        } else {
          invalidCount++;
        }
      }

      setState(() {});
      _notifySelection();
      AppHelpers.showSuccessToast(
        'CSV processed: $validCount valid, $invalidCount invalid users'
      );
    } catch (e) {
      AppHelpers.showErrorToast('Failed to process CSV: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.info,
                      size: 16,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Text(
                      'Select Participants',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: AppSizes.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Text(
                    '${selectedUserIds.length} selected',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Search users',
                    controller: _searchController,
                    prefixIcon: Icons.search,
                    onChanged: (_) => _filterUsers(),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                IconButton(
                  onPressed: _uploadCsv,
                  icon: const Icon(Icons.upload_file),
                  tooltip: 'Upload CSV',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.success.withOpacity(0.1),
                    foregroundColor: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),

            Row(
              children: [
                TextButton.icon(
                  onPressed: _selectAll,
                  icon: Icon(Icons.check_box, color: AppColors.success),
                  label: Text(
                    'Select All',
                    style: TextStyle(color: AppColors.success),
                  ),
                ),
                TextButton.icon(
                  onPressed: _deselectAll,
                  icon: Icon(Icons.check_box_outline_blank, color: AppColors.error),
                  label: Text(
                    'Deselect All',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
                const Spacer(),
                Text(
                  '${filteredUsers.length} users',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.gray600,
                  ),
                ),
              ],
            ),
            const Divider(),

            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.lg),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filteredUsers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: AppColors.gray400,
                      ),
                      const SizedBox(height: AppSizes.md),
                      Text(
                        'No users found',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    final userId = user['id'];
                    final isSelected = selectedUserIds.contains(userId);
                    
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (_) => _toggleUser(userId),
                      title: Text(
                        user['name'] ?? 'Unknown',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${user['user_id']} • ${user['departments']?['name'] ?? 'No Dept'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.gray600,
                        ),
                      ),
                      secondary: CircleAvatar(
                        backgroundColor: isSelected ? AppColors.primary : AppColors.gray300,
                        child: Text(
                          user['name'][0].toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.gray700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      activeColor: AppColors.primary,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

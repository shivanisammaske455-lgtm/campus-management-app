import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/issue_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/issue_card.dart';

enum IssuesTab {
  myReports,
  allCampus;

  String get label {
    switch (this) {
      case IssuesTab.myReports:
        return 'My reports';
      case IssuesTab.allCampus:
        return 'All campus';
    }
  }
}

class IssuesScreen extends ConsumerStatefulWidget {
  const IssuesScreen({super.key});

  @override
  ConsumerState<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends ConsumerState<IssuesScreen> {
  IssuesTab _selectedTab = IssuesTab.myReports;
  IssueStatus? _selectedStatusFilter; // null means 'All'

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    // Watch live streams based on active segmented control
    final issuesAsync = _selectedTab == IssuesTab.myReports
        ? ref.watch(myIssuesStreamProvider(currentUser.uid))
        : ref.watch(allIssuesStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.offWhiteBg,
      appBar: AppBar(
        title: const Text('Campus Issues'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              if (_selectedTab == IssuesTab.myReports) {
                ref.invalidate(myIssuesStreamProvider(currentUser.uid));
              } else {
                ref.invalidate(allIssuesStreamProvider);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ---------------------------------------------------------
          // 1. Segmented Control: "My reports | All campus"
          // ---------------------------------------------------------
          Container(
            color: AppTheme.surfaceWhite,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.offWhiteBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: IssuesTab.values.map((tab) {
                  final isSelected = _selectedTab == tab;
                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedTab = tab;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ---------------------------------------------------------
          // 2. Status Filter Chips: All, Reported, In progress, Resolved
          // ---------------------------------------------------------
          Container(
            color: AppTheme.surfaceWhite,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // 'All' filter chip
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _selectedStatusFilter == null,
                      selectedColor: AppTheme.primaryGreen.withOpacity(0.15),
                      checkmarkColor: AppTheme.primaryGreen,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: _selectedStatusFilter == null
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: _selectedStatusFilter == null
                            ? AppTheme.primaryGreen
                            : AppTheme.textPrimary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _selectedStatusFilter == null
                              ? AppTheme.primaryGreen
                              : AppTheme.borderLight,
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatusFilter = null;
                        });
                      },
                    ),
                  ),

                  // Reported, In progress, Resolved
                  ...IssueStatus.values.map((status) {
                    final isSelected = _selectedStatusFilter == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(status.label),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryGreen.withOpacity(0.15),
                        checkmarkColor: AppTheme.primaryGreen,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? AppTheme.primaryGreen
                              : AppTheme.textPrimary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primaryGreen
                                : AppTheme.borderLight,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedStatusFilter = selected ? status : null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderLight),

          // ---------------------------------------------------------
          // 3. Issue Cards List with Live Firestore Stream
          // ---------------------------------------------------------
          Expanded(
            child: issuesAsync.when(
              data: (issues) {
                // Apply active status filter
                var filteredList = issues;
                if (_selectedStatusFilter != null) {
                  filteredList = issues
                      .where((i) => i.status == _selectedStatusFilter)
                      .toList();
                }

                if (filteredList.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 54,
                            color: AppTheme.textSecondary.withOpacity(0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedStatusFilter == null
                                ? (_selectedTab == IssuesTab.myReports
                                    ? 'No reports submitted by you yet'
                                    : 'No campus issues reported')
                                : 'No ${_selectedStatusFilter!.label.toLowerCase()} issues found',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Pull down to refresh or change filters above.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    if (_selectedTab == IssuesTab.myReports) {
                      ref.invalidate(myIssuesStreamProvider(currentUser.uid));
                    } else {
                      ref.invalidate(allIssuesStreamProvider);
                    }
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final issue = filteredList[index];

                      return IssueCard(
                        issue: issue,
                        currentUserId: currentUser.uid,
                        showMeTooButton: _selectedTab == IssuesTab.allCampus,
                        onMeTooTap: () async {
                          final firestoreService =
                              ref.read(firestoreServiceProvider);
                          final hasUserMeToo = issue.hasMeToo(currentUser.uid);

                          try {
                            await firestoreService.toggleMeToo(
                              issueId: issue.id,
                              uid: currentUser.uid,
                              isCurrentlyAdded: hasUserMeToo,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not update Me too: $e'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        onTap: () {
                          context.push(
                            '/issue-detail/${issue.id}',
                            extra: issue,
                          );
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Error loading issues: $error',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

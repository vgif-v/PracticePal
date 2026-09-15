import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../models/student.dart';

class StudentTrackingScreen extends StatefulWidget {
  final StudentData? student;

  const StudentTrackingScreen({super.key, this.student});

  @override
  State<StudentTrackingScreen> createState() => _StudentTrackingScreenState();
}

class _StudentTrackingScreenState extends State<StudentTrackingScreen> {
  late StudentData _student;
  late List<SessionItem> _sessions;
  late int _cycleNumber;

  @override
  void initState() {
    super.initState();
    _student = widget.student ?? StudentData.defaultStudent();
    // Create a mutable copy of sessions so the user can toggle stars and add more
    _sessions = _student.sessions
        .map((s) => SessionItem(date: s.date, isCompleted: s.isCompleted))
        .toList();
    _cycleNumber = _student.cycleNumber;
  }

  void _toggleSession(int index) {
    setState(() {
      _sessions[index].isCompleted = !_sessions[index].isCompleted;
    });

    final isNowDone = _sessions[index].isCompleted;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isNowDone
              ? '✨ Session ${index + 1} marked completed! Star awarded!'
              : 'Session ${index + 1} marked incomplete.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isNowDone
            ? KineticColors.secondary
            : KineticColors.deepSlate,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticRadii.dflt),
        ),
      ),
    );
  }

  void _addNewSession() {
    setState(() {
      final nextNum = _sessions.length + 1;
      _sessions.add(
        SessionItem(
          date: 'Nov ${nextNum < 10 ? '0$nextNum' : nextNum}',
          isCompleted: false,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added session #${_sessions.length} to Cycle #$_cycleNumber!',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: KineticColors.neonTeal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticRadii.dflt),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _sessions.where((s) => s.isCompleted).length;

    return Scaffold(
      backgroundColor: KineticColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: KineticColors.deepSlate,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            // Small app name/logo at the top
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: KineticColors.electricCoral,
                    borderRadius: BorderRadius.circular(KineticRadii.sm),
                  ),
                  child: const Icon(
                    Icons.sports_gymnastics_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                RichText(
                  text: TextSpan(
                    style: KineticTypography.titleMd.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Practice',
                        style: TextStyle(color: KineticColors.deepSlate),
                      ),
                      TextSpan(
                        text: 'Pal',
                        style: TextStyle(color: KineticColors.electricCoral),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Trainer's name displayed below that
            Text(
              'Trainer: ${_student.trainerName}',
              style: KineticTypography.bodySm.copyWith(
                color: KineticColors.outline,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.share_outlined,
              color: KineticColors.deepSlate,
            ),
            tooltip: 'Share Progress',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'Progress summary ready to export or share with parents!',
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KineticRadii.dflt),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: KineticSpacing.gutter,
            vertical: KineticSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Student's name, age, and address in a styled card
              _buildStudentInfoCard(completedCount),
              const SizedBox(height: KineticSpacing.lg),

              // Cycle Header with "+" Icon to customize sessions
              _buildCycleHeader(),
              const SizedBox(height: KineticSpacing.sm),

              // Row with GridView.count on left (Expanded) and Payment Due column on right
              _buildTrackingAndPaymentsSection(),

              const SizedBox(height: KineticSpacing.lg),

              // Encouraging Progress Banner
              _buildEncouragementCard(completedCount),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentInfoCard(int completedCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        boxShadow: KineticShadows.level1,
        border: Border.all(
          color: KineticColors.surfaceContainerHighest,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(KineticSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: KineticColors.accentLilac.withValues(
                  alpha: 0.18,
                ),
                child: Text(
                  _student.name.split(' ').map((e) => e[0]).take(2).join(),
                  style: KineticTypography.headlineSm.copyWith(
                    color: KineticColors.accentLilac,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: KineticSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _student.name,
                      style: KineticTypography.headlineSm.copyWith(
                        color: KineticColors.deepSlate,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: KineticColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(
                              KineticRadii.sm,
                            ),
                          ),
                          child: Text(
                            'Age ${_student.age}',
                            style: KineticTypography.labelSm.copyWith(
                              color: KineticColors.deepSlate,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: KineticColors.neonTeal.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(
                              KineticRadii.sm,
                            ),
                          ),
                          child: Text(
                            '$completedCount/${_sessions.length} Stars',
                            style: KineticTypography.labelSm.copyWith(
                              color: KineticColors.secondary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KineticSpacing.sm),
          const Divider(height: 16, thickness: 1, color: Color(0xFFF0EFFF)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: KineticColors.outline,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _student.address,
                  style: KineticTypography.bodySm.copyWith(
                    color: KineticColors.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCycleHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KineticSpacing.md,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [KineticColors.coolDark, KineticColors.coolBlue],
                ),
                borderRadius: BorderRadius.circular(KineticRadii.full),
                boxShadow: [
                  BoxShadow(
                    color: KineticColors.coolBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.repeat_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Cycle No. $_cycleNumber',
                    style: KineticTypography.labelLg.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_sessions.length} Sessions)',
              style: KineticTypography.bodySm.copyWith(
                color: KineticColors.coolMutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        // "+" IconButton near the grid to customize the number of sessions
        Tooltip(
          message: 'Add / Customize Sessions',
          child: Material(
            color: KineticColors.neonTeal.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(KineticRadii.full),
            child: InkWell(
              onTap: _addNewSession,
              borderRadius: BorderRadius.circular(KineticRadii.full),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: KineticColors.neonTeal, width: 1.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: KineticColors.secondary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingAndPaymentsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If width is under 600, stack payment cards under the cycle grid
        final isSmallScreen = constraints.maxWidth < 600;

        final gridCard = Container(
          padding: const EdgeInsets.symmetric(
            vertical: KineticSpacing.md,
            horizontal: KineticSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(KineticRadii.md),
            boxShadow: KineticShadows.level1,
            border: Border.all(
              color: KineticColors.coolBorder,
              width: 1.5,
            ),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 6,
              childAspectRatio: isSmallScreen ? 0.95 : 1.0,
            ),
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              final session = _sessions[index];
              return _buildSessionGridItem(index, session);
            },
          ),
        );

        if (isSmallScreen) {
          // Responsive: Payment cards placed UNDER the cycle grid on small widths
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              gridCard,
              if (_student.payments.isNotEmpty) ...[
                const SizedBox(height: KineticSpacing.md),
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: KineticColors.coolDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tuition & Fees Due',
                      style: KineticTypography.labelMd.copyWith(
                        color: KineticColors.coolDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KineticSpacing.xs),
                constraints.maxWidth > 380
                    ? Row(
                        children: _student.payments.map((payment) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: _buildPaymentDueCard(payment),
                            ),
                          );
                        }).toList(),
                      )
                    : Column(
                        children: _student.payments.map((payment) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: _buildPaymentDueCard(payment),
                          );
                        }).toList(),
                      ),
              ],
            ],
          );
        }

        // On wider screens: Side-by-side layout
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: gridCard,
            ),
            const SizedBox(width: KineticSpacing.md),
            if (_student.payments.isNotEmpty)
              Expanded(
                flex: 3,
                child: Column(
                  children: _student.payments.map((payment) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _buildPaymentDueCard(payment),
                    );
                  }).toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildSessionGridItem(int index, SessionItem session) {
    final isDone = session.isCompleted;

    return InkWell(
      onTap: () => _toggleSession(index),
      borderRadius: BorderRadius.circular(KineticRadii.full),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? KineticColors.sunnyGold.withValues(alpha: 0.18)
                  : KineticColors.surfaceContainerLow,
              border: Border.all(
                color: isDone
                    ? KineticColors.sunnyGold
                    : KineticColors.surfaceDim,
                width: 2.0,
              ),
              boxShadow: isDone
                  ? [
                      BoxShadow(
                        color: KineticColors.sunnyGold.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isDone ? Icons.star_rounded : Icons.circle_outlined,
              color: isDone
                  ? const Color(0xFFD99000)
                  : KineticColors.outlineVariant,
              size: 26,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            session.date,
            style: KineticTypography.labelSm.copyWith(
              color: isDone ? KineticColors.deepSlate : KineticColors.outline,
              fontWeight: isDone ? FontWeight.w800 : FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDueCard(PaymentDueItem payment) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: payment.isUrgent
              ? const [Color(0xFFFF6F43), Color(0xFFFF8B5E)]
              : const [Color(0xFFFF9500), Color(0xFFFFB03A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(KineticRadii.dflt),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9500).withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PAYMENT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Icon(
                Icons.receipt_long_rounded,
                color: Colors.white,
                size: 14,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            payment.amount,
            style: KineticTypography.titleMd.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(
            payment.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              payment.dueDate,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEncouragementCard(int completedCount) {
    final remaining = _sessions.length - completedCount;
    return Container(
      padding: const EdgeInsets.all(KineticSpacing.md),
      decoration: BoxDecoration(
        color: KineticColors.neonTeal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KineticRadii.md),
        border: Border.all(
          color: KineticColors.neonTeal.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: KineticColors.neonTeal,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: KineticColors.deepSlate,
              size: 24,
            ),
          ),
          const SizedBox(width: KineticSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remaining == 0
                      ? '🎉 Cycle Completed! Super star!'
                      : '⚡ $remaining more sessions to complete Cycle #$_cycleNumber!',
                  style: KineticTypography.titleMd.copyWith(
                    color: KineticColors.deepSlate,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap any session circle above to toggle practice star.',
                  style: KineticTypography.bodySm.copyWith(
                    color: KineticColors.outline,
                    fontWeight: FontWeight.w600,
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

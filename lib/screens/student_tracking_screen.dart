import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../theme/theme.dart';
import '../models/student.dart';
import '../services/class_service.dart';
import '../utils/image_saver.dart';

// ---------------------------------------------------------------------------
// StudentTrackingScreen
// isTrainerView = true  → trainer can toggle sessions, edit payments, add cycles
// isTrainerView = false → student sees read-only view
// ---------------------------------------------------------------------------
class StudentTrackingScreen extends StatefulWidget {
  final StudentData? student;
  final bool isTrainerView;
  final String classId;  // needed for Firestore writes (trainer only)

  const StudentTrackingScreen({
    super.key,
    this.student,
    this.isTrainerView = false,
    this.classId = '',
  });

  @override
  State<StudentTrackingScreen> createState() => _StudentTrackingScreenState();
}

class _StudentTrackingScreenState extends State<StudentTrackingScreen> {
  final ClassService _classService = ClassService();
  late StudentData _student;
  late int _selectedCycleIndex; // index into allCycles list
  bool _isSaving = false;
  bool _isGeneratingImage = false;
  final GlobalKey _shareCardKey = GlobalKey();

  /// Central banner/toast helper: 2-second display, clears queue so it doesn't stack
  void _showNotificationBanner(String message, {bool isSuccess = true, bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? KineticColors.error
              : (isSuccess ? KineticColors.secondary : KineticColors.deepSlate),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KineticRadii.dflt),
          ),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    _student = widget.student ?? StudentData.defaultStudent();
    // Default to the last (active) cycle
    _selectedCycleIndex = (_student.allCycles.length - 1).clamp(0, 99);
  }

  // Active cycle based on switcher selection
  CycleData get _activeCycle {
    final cycles = _student.allCycles;
    if (cycles.isEmpty) {
      return CycleData(
        cycleNumber: _student.cycleNumber,
        sessions: _student.sessions,
        payments: _student.payments,
      );
    }
    return cycles[_selectedCycleIndex.clamp(0, cycles.length - 1)];
  }

  bool get _isActiveCycle =>
      _activeCycle.cycleNumber == _student.cycleNumber;

  // ---------------------------------------------------------------------------
  // Actions — writes to Firestore (trainer only)
  // ---------------------------------------------------------------------------

  Future<void> _toggleSession(int sessionIndex) async {
    if (!widget.isTrainerView || widget.classId.isEmpty || _isSaving) return;
    final current = _activeCycle.sessions[sessionIndex].isCompleted;
    setState(() => _isSaving = true);
    try {
      await _classService.toggleSessionCompleted(
        classId: widget.classId,
        studentName: _student.name,
        cycleNumber: _activeCycle.cycleNumber,
        sessionIndex: sessionIndex,
        isCompleted: !current,
      );

      // Refresh local state
      final doc = await _classService.db
          .collection('classes')
          .doc(widget.classId)
          .get();
      final updatedClass = ClassModel.fromFirestore(doc);
      final updated = updatedClass.students.firstWhere(
        (s) => s.name.toLowerCase() == _student.name.toLowerCase(),
        orElse: () => _student,
      );
      if (mounted) {
        setState(() {
          _student = updated;
          // Keep selectedCycleIndex valid
          _selectedCycleIndex =
              _selectedCycleIndex.clamp(0, _student.allCycles.length - 1);
        });
      }

      if (mounted) {
        final nowDone = !current;
        _showNotificationBanner(
          nowDone
              ? '⭐ Session ${sessionIndex + 1} marked complete!'
              : 'Session ${sessionIndex + 1} marked incomplete.',
          isSuccess: nowDone,
        );
      }
    } catch (e) {
      if (mounted) {
        _showNotificationBanner('Error saving session: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _togglePayment(int paymentIndex) async {
    if (!widget.isTrainerView || widget.classId.isEmpty || _isSaving) return;
    final current = _activeCycle.payments[paymentIndex].isPaid;
    setState(() => _isSaving = true);
    try {
      await _classService.togglePaymentPaid(
        classId: widget.classId,
        studentName: _student.name,
        cycleNumber: _activeCycle.cycleNumber,
        paymentIndex: paymentIndex,
        isPaid: !current,
      );
      await _refreshStudent();
      if (mounted) {
        _showNotificationBanner(
          !current ? '✓ Payment marked paid!' : 'Payment marked unpaid.',
          isSuccess: !current,
        );
      }
    } catch (e) {
      if (mounted) {
        _showNotificationBanner('Error updating payment: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editPaymentDueDate(int paymentIndex) async {
    if (!widget.isTrainerView || widget.classId.isEmpty || _isSaving) return;
    final existing = _activeCycle.payments[paymentIndex].customDueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null || !mounted) return;
    setState(() => _isSaving = true);
    try {
      await _classService.updatePaymentDueDate(
        classId: widget.classId,
        studentName: _student.name,
        cycleNumber: _activeCycle.cycleNumber,
        paymentIndex: paymentIndex,
        newDate: picked,
      );
      await _refreshStudent();
      if (mounted) {
        _showNotificationBanner('📅 Due date updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showNotificationBanner('Error updating due date: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editPaymentAmount(int paymentIndex) async {
    if (!widget.isTrainerView || widget.classId.isEmpty || _isSaving) return;
    final currentAmount = _activeCycle.payments[paymentIndex].amount;
    String initialNumber =
        currentAmount.replaceAll('₱', '').replaceAll(',', '').trim();
    if (initialNumber == '0') initialNumber = '';
    final ctrl = TextEditingController(text: initialNumber);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticRadii.md),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: KineticColors.sunnyGold.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Text('₱',
                  style: TextStyle(
                      color: KineticColors.sunnyGold,
                      fontSize: 18,
                      fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Edit Payment ${paymentIndex + 1} Amount',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _activeCycle.payments[paymentIndex].label,
              style: const TextStyle(
                  color: KineticColors.coolMutedText, fontSize: 13),
            ),
            const SizedBox(height: KineticSpacing.md),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Payment Amount',
                prefixText: '₱ ',
                prefixStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: KineticColors.coolDark,
                ),
                hintText: 'e.g. 1500',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(KineticRadii.dflt),
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = ctrl.text.trim();
              if (raw.isEmpty) {
                Navigator.pop(ctx, '₱0');
                return;
              }
              final clean = raw
                  .replaceAll('₱', '')
                  .replaceAll('Php', '')
                  .replaceAll('PHP', '')
                  .trim();
              Navigator.pop(ctx, '₱$clean');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: KineticColors.coolDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Amount'),
          ),
        ],
      ),
    );

    if (result == null) return;
    setState(() => _isSaving = true);
    try {
      await _classService.updatePaymentAmount(
        classId: widget.classId,
        studentName: _student.name,
        cycleNumber: _activeCycle.cycleNumber,
        paymentIndex: paymentIndex,
        newAmount: result,
      );
      await _refreshStudent();
      if (mounted) {
        _showNotificationBanner('Payment amount updated to $result!');
      }
    } catch (e) {
      if (mounted) {
        _showNotificationBanner('Error updating payment amount: $e',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _startNewCycle() async {
    if (!widget.isTrainerView || widget.classId.isEmpty || _isSaving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start New Cycle?'),
        content: Text(
          'This will archive Cycle ${_student.cycleNumber} and start Cycle ${_student.cycleNumber + 1} '
          'with 8 fresh sessions and 2 new payment records.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: KineticColors.coolDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Cycle'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      await _classService.addNewCycle(
        classId: widget.classId,
        studentName: _student.name,
      );
      await _refreshStudent();
      // Jump to the newly created active cycle
      if (mounted) {
        setState(() {
          _selectedCycleIndex = _student.allCycles.length - 1;
        });
        _showNotificationBanner('🎉 Cycle ${_student.cycleNumber} started!');
      }
    } catch (e) {
      if (mounted) {
        _showNotificationBanner('Error starting new cycle: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editSessionDate(int sessionIndex) async {
    if (!widget.isTrainerView || widget.classId.isEmpty || _isSaving) return;
    final ctrl = TextEditingController(
      text: _activeCycle.sessions[sessionIndex].date,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Session ${sessionIndex + 1} Label'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Session label',
            hintText: 'e.g. Oct 05, Week 3...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _addAnotherSession();
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Another Session'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: KineticColors.coolDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await _classService.updateSessionDate(
        classId: widget.classId,
        studentName: _student.name,
        cycleNumber: _activeCycle.cycleNumber,
        sessionIndex: sessionIndex,
        newDate: result,
      );
      await _refreshStudent();
      if (mounted) {
        _showNotificationBanner('Session ${sessionIndex + 1} label updated!');
      }
    } catch (e) {
      if (mounted) {
        _showNotificationBanner('Error updating session: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addAnotherSession({String? defaultLabel}) async {
    if (!widget.isTrainerView || widget.classId.isEmpty || _isSaving) return;
    final nextNumber = _activeCycle.sessions.length + 1;
    final labelCtrl = TextEditingController(
      text: defaultLabel ?? 'Session $nextNumber',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticRadii.md),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: KineticColors.coolBlue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_circle_outline_rounded,
                  color: KineticColors.coolBlue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Add Session $nextNumber',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add another session to this cycle for this student.',
              style: TextStyle(
                  color: KineticColors.coolMutedText, fontSize: 13),
            ),
            const SizedBox(height: KineticSpacing.md),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(
                labelText: 'Session label',
                hintText: 'e.g. Session 9, Makeup Session...',
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: KineticColors.coolDark,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add Session'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isSaving = true);
    try {
      await _classService.addSession(
        classId: widget.classId,
        studentName: _student.name,
        cycleNumber: _activeCycle.cycleNumber,
        sessionLabel: labelCtrl.text.trim(),
      );
      await _refreshStudent();
      if (mounted) {
        _showNotificationBanner(
            'Session $nextNumber added to Cycle ${_activeCycle.cycleNumber}!');
      }
    } catch (e) {
      if (mounted) {
        _showNotificationBanner('Error adding session: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Generates high-res image of the student tracking card and downloads/previews it
  Future<void> _shareProgressCard() async {
    if (_isGeneratingImage) return;
    setState(() => _isGeneratingImage = true);

    try {
      // Ensure layout is rendered completely
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _shareCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _showNotificationBanner('Could not capture progress card. Please try again.', isError: true);
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showNotificationBanner('Failed to format card image.', isError: true);
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final sanitizedName = _student.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
      final filename = 'practicepal_${sanitizedName}_cycle${_activeCycle.cycleNumber}.png';

      // Download file to the user's browser/device
      downloadImageBytes(pngBytes, filename);

      if (mounted) {
        _showNotificationBanner('📸 Progress card image generated & downloaded!');
        _showImagePreviewDialog(pngBytes, filename);
      }
    } catch (e) {
      if (mounted) {
        _showNotificationBanner('Failed to generate image: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isGeneratingImage = false);
    }
  }

  void _showImagePreviewDialog(Uint8List pngBytes, String filename) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: KineticColors.coolBlue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          color: KineticColors.secondary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Card Image Generated!',
                            style: KineticTypography.titleMd.copyWith(
                                fontWeight: FontWeight.w800,
                                color: KineticColors.deepSlate),
                          ),
                          Text(
                            'Downloaded as $filename',
                            style: KineticTypography.bodySm.copyWith(
                                color: KineticColors.outline, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: KineticColors.deepSlate),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KineticColors.coolBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      child: Image.memory(
                        pngBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download Again'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KineticColors.coolDark,
                          side: const BorderSide(color: KineticColors.coolBorder),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          downloadImageBytes(pngBytes, filename);
                          _showNotificationBanner('📥 Download started again!');
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.done_rounded, size: 18),
                        label: const Text('Done'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KineticColors.coolDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshStudent() async {
    if (widget.classId.isEmpty) return;
    final doc = await _classService.db
        .collection('classes')
        .doc(widget.classId)
        .get();
    if (!doc.exists) return;
    final updatedClass = ClassModel.fromFirestore(doc);
    final updated = updatedClass.students.firstWhere(
      (s) => s.name.toLowerCase() == _student.name.toLowerCase(),
      orElse: () => _student,
    );
    if (mounted) {
      setState(() {
        _student = updated;
        _selectedCycleIndex =
            _selectedCycleIndex.clamp(0, (_student.allCycles.length - 1).clamp(0, 99));
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sessions = _activeCycle.sessions;
    final completedCount = sessions.where((s) => s.isCompleted).length;
    final cycles = _student.allCycles;

    return Scaffold(
      backgroundColor: KineticColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: KineticColors.deepSlate),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(KineticRadii.sm),
                    border: Border.all(
                      color: KineticColors.coolBorder.withValues(alpha: 0.8),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                RichText(
                  text: TextSpan(
                    style: KineticTypography.titleMd.copyWith(
                        fontWeight: FontWeight.w900, fontSize: 16),
                    children: const [
                      TextSpan(
                          text: 'Practice',
                          style: TextStyle(color: KineticColors.deepSlate)),
                      TextSpan(
                          text: 'Pal',
                          style: TextStyle(color: KineticColors.electricCoral)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              widget.isTrainerView
                  ? '${_student.name} · Trainer View'
                  : 'Trainer: ${_student.trainerName}',
              style: KineticTypography.bodySm.copyWith(
                  color: KineticColors.outline,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          IconButton(
            icon: _isGeneratingImage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KineticColors.deepSlate,
                    ),
                  )
                : const Icon(Icons.share_rounded,
                    color: KineticColors.deepSlate),
            tooltip: 'Share Progress Card (Generate Image)',
            onPressed: (_isSaving || _isGeneratingImage) ? null : _shareProgressCard,
          ),
          if (widget.isTrainerView && widget.classId.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_chart_rounded,
                  color: KineticColors.deepSlate),
              tooltip: 'Start New Cycle',
              onPressed: _isSaving ? null : _startNewCycle,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: KineticSpacing.gutter, vertical: KineticSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cycle switcher (tabs)
              if (cycles.length > 1) ...[
                _buildCycleSwitcher(cycles),
                const SizedBox(height: KineticSpacing.sm),
              ],

              // Visual Shareable Progress Card wrapped in RepaintBoundary
              RepaintBoundary(
                key: _shareCardKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(KineticRadii.lg),
                    boxShadow: [
                      BoxShadow(
                        color: KineticColors.deepSlate.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: KineticColors.coolBorder, width: 1.5),
                  ),
                  padding: const EdgeInsets.all(KineticSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildShareCardBanner(),
                      const SizedBox(height: KineticSpacing.md),
                      _buildStudentInfoCard(completedCount),
                      const SizedBox(height: KineticSpacing.md),
                      _buildCycleHeader(sessions),
                      const SizedBox(height: KineticSpacing.sm),
                      _buildTrackingAndPaymentsSection(sessions),
                      const SizedBox(height: KineticSpacing.md),
                      _buildShareCardFooter(completedCount, sessions.length),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: KineticSpacing.md),

              // Action button to share/generate image
              _buildShareActionButton(),

              const SizedBox(height: KineticSpacing.lg),

              // Encouragement banner
              _buildEncouragementCard(completedCount, sessions.length),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareCardBanner() {
    final now = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${months[now.month - 1]} ${now.day}, ${now.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: KineticColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(KineticRadii.sm),
        border: Border.all(color: KineticColors.coolBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(KineticRadii.sm),
                  border: Border.all(
                    color: KineticColors.coolBorder.withValues(alpha: 0.8),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PRACTICEPAL PROGRESS CARD',
                style: KineticTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: KineticColors.deepSlate,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          Text(
            dateStr,
            style: KineticTypography.bodySm.copyWith(
              color: KineticColors.outline,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareCardFooter(int completed, int total) {
    final pct = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final pctInt = (pct * 100).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(KineticRadii.sm),
        border: Border.all(color: KineticColors.coolBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cycle Progress',
                style: KineticTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: KineticColors.deepSlate,
                ),
              ),
              Text(
                '$completed / $total Sessions ($pctInt%)',
                style: KineticTypography.labelSm.copyWith(
                  fontWeight: FontWeight.w800,
                  color: KineticColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(KineticRadii.full),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: KineticColors.coolBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(KineticColors.secondary),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_rounded, size: 12, color: KineticColors.neonTeal),
              const SizedBox(width: 4),
              Text(
                'Verified PracticePal Achievement Record',
                style: KineticTypography.bodySm.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: KineticColors.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareActionButton() {
    return ElevatedButton.icon(
      icon: _isGeneratingImage
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.share_rounded, size: 18),
      label: Text(
        _isGeneratingImage ? 'Generating Image...' : 'Share Progress Card · Generate Image',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: KineticColors.coolDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KineticRadii.md),
        ),
        elevation: 2,
      ),
      onPressed: (_isSaving || _isGeneratingImage) ? null : _shareProgressCard,
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Widget _buildCycleSwitcher(List<CycleData> cycles) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: cycles.length,
        itemBuilder: (context, i) {
          final isSelected = i == _selectedCycleIndex;
          final cycle = cycles[i];
          return GestureDetector(
            onTap: () => setState(() => _selectedCycleIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [KineticColors.coolDark, KineticColors.coolBlue])
                    : null,
                color: isSelected ? null : KineticColors.coolInputBg,
                borderRadius: BorderRadius.circular(KineticRadii.full),
                border: Border.all(
                    color: isSelected
                        ? KineticColors.coolBlue
                        : KineticColors.coolBorder),
              ),
              child: Text(
                'Cycle ${cycle.cycleNumber}${cycle.cycleNumber == _student.cycleNumber ? ' ✦' : ''}',
                style: KineticTypography.labelSm.copyWith(
                  color: isSelected ? Colors.white : KineticColors.coolDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudentInfoCard(int completedCount) {
    final sessions = _activeCycle.sessions;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        boxShadow: KineticShadows.level1,
        border: Border.all(
            color: KineticColors.surfaceContainerHighest, width: 1.5),
      ),
      padding: const EdgeInsets.all(KineticSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    KineticColors.accentLilac.withValues(alpha: 0.18),
                child: Text(
                  _student.name.split(' ').map((e) => e[0]).take(2).join(),
                  style: KineticTypography.headlineSm.copyWith(
                      color: KineticColors.accentLilac,
                      fontWeight: FontWeight.w800),
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
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (_student.age > 0)
                          _buildInfoPill('Age ${_student.age}',
                              KineticColors.surfaceContainerHigh,
                              KineticColors.deepSlate),
                        _buildInfoPill(
                            '$completedCount/${sessions.length} ⭐',
                            KineticColors.neonTeal.withValues(alpha: 0.2),
                            KineticColors.secondary),
                        if (_student.isManuallyAdded)
                          _buildInfoPill('Manual Enroll',
                              KineticColors.sunnyGold.withValues(alpha: 0.2),
                              KineticColors.sunnyGold),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_student.address.isNotEmpty) ...[
            const SizedBox(height: KineticSpacing.sm),
            const Divider(height: 16, thickness: 1, color: Color(0xFFF0EFFF)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: KineticColors.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _student.address,
                    style: KineticTypography.bodySm.copyWith(
                        color: KineticColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoPill(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(KineticRadii.sm)),
      child: Text(label,
          style: KineticTypography.labelSm
              .copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildCycleHeader(List<SessionItem> sessions) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: KineticSpacing.md, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [KineticColors.coolDark, KineticColors.coolBlue]),
                borderRadius: BorderRadius.circular(KineticRadii.full),
                boxShadow: [
                  BoxShadow(
                      color: KineticColors.coolBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.repeat_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'Cycle ${_activeCycle.cycleNumber}${_isActiveCycle ? '' : ' (Archived)'}',
                    style: KineticTypography.labelLg.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${sessions.length} Sessions)',
              style: KineticTypography.bodySm.copyWith(
                  color: KineticColors.coolMutedText,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
        // Edit session dates button (trainer only, active cycle only)
        if (widget.isTrainerView && _isActiveCycle && widget.classId.isNotEmpty)
          Tooltip(
            message: 'Edit Session Labels',
            child: Material(
              color: KineticColors.coolInputBg,
              borderRadius: BorderRadius.circular(KineticRadii.full),
              child: InkWell(
                onTap: _isSaving
                    ? null
                    : () => _showSessionDatesSheet(sessions),
                borderRadius: BorderRadius.circular(KineticRadii.full),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: KineticColors.coolBorder, width: 1.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_calendar_rounded,
                      color: KineticColors.coolDark, size: 18),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showSessionDatesSheet(List<SessionItem> sessions) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: KineticColors.coolBorder,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.edit_calendar_rounded,
                        color: KineticColors.coolDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Edit Session Labels',
                        style: KineticTypography.titleMd.copyWith(
                            fontWeight: FontWeight.w800,
                            color: KineticColors.coolDark),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _addAnotherSession();
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Session',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      style: TextButton.styleFrom(
                        foregroundColor: KineticColors.coolBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: sessions.length,
                  itemBuilder: (_, i) {
                    final session = sessions[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor:
                            KineticColors.coolBlue.withValues(alpha: 0.12),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                              color: KineticColors.coolBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 12),
                        ),
                      ),
                      title: Text(session.date,
                          style: KineticTypography.bodyMd
                              .copyWith(fontWeight: FontWeight.w600)),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_rounded,
                            size: 18, color: KineticColors.coolMutedText),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _editSessionDate(i);
                        },
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: KineticColors.coolBorder)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _addAnotherSession();
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add Another Session',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KineticColors.coolDark,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(KineticRadii.full)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackingAndPaymentsSection(List<SessionItem> sessions) {
    final payments = _activeCycle.payments;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final gridCard = _buildSessionGrid(sessions, isSmall);

        if (isSmall) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              gridCard,
              if (payments.isNotEmpty) ...[
                const SizedBox(height: KineticSpacing.md),
                Row(children: [
                  const Icon(Icons.receipt_long_rounded,
                      size: 16, color: KineticColors.coolDark),
                  const SizedBox(width: 6),
                  Text('Tuition & Fees',
                      style: KineticTypography.labelMd.copyWith(
                          color: KineticColors.coolDark,
                          fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: KineticSpacing.xs),
                constraints.maxWidth > 380
                    ? Row(
                        children: payments.asMap().entries.map((e) {
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: _buildPaymentCard(e.value, e.key),
                            ),
                          );
                        }).toList(),
                      )
                    : Column(
                        children: payments.asMap().entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildPaymentCard(e.value, e.key),
                          );
                        }).toList(),
                      ),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: gridCard),
            if (payments.isNotEmpty) ...[
              const SizedBox(width: KineticSpacing.md),
              Expanded(
                flex: 3,
                child: Column(
                  children: payments.asMap().entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildPaymentCard(e.value, e.key),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSessionGrid(List<SessionItem> sessions, bool isSmall) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: KineticSpacing.md, horizontal: KineticSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(KineticRadii.md),
        boxShadow: KineticShadows.level1,
        border: Border.all(color: KineticColors.coolBorder, width: 1.5),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 6,
          childAspectRatio: isSmall ? 0.95 : 1.0,
        ),
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          return _buildSessionGridItem(index, sessions[index]);
        },
      ),
    );
  }

  Widget _buildSessionGridItem(int index, SessionItem session) {
    final isDone = session.isCompleted;
    final canTap =
        widget.isTrainerView && _isActiveCycle && widget.classId.isNotEmpty;

    return InkWell(
      onTap: canTap && !_isSaving ? () => _toggleSession(index) : null,
      onLongPress: canTap && !_isSaving && widget.isTrainerView
          ? () => _editSessionDate(index)
          : null,
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
                          color:
                              KineticColors.sunnyGold.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(PaymentDueItem payment, int index) {
    final isPaid = payment.isPaid;
    final canEdit =
        widget.isTrainerView && _isActiveCycle && widget.classId.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPaid
              ? const [Color(0xFF22C55E), Color(0xFF16A34A)]
              : payment.isUrgent
                  ? const [Color(0xFFFF6F43), Color(0xFFFF8B5E)]
                  : const [Color(0xFFFF9500), Color(0xFFFFB03A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(KineticRadii.dflt),
        boxShadow: [
          BoxShadow(
            color: (isPaid
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFFF9500))
                .withValues(alpha: 0.28),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                  isPaid ? 'PAID ✓' : 'PAYMENT',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canEdit && !_isSaving) ...[
                    GestureDetector(
                      onTap: () => _editPaymentAmount(index),
                      child: const Tooltip(
                        message: 'Edit Payment Amount',
                        child: Icon(Icons.edit_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _editPaymentDueDate(index),
                      child: const Tooltip(
                        message: 'Set Due Date',
                        child: Icon(Icons.calendar_today_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _togglePayment(index),
                      child: Tooltip(
                        message: isPaid ? 'Mark Unpaid' : 'Mark Paid',
                        child: Icon(
                          isPaid
                              ? Icons.cancel_outlined
                              : Icons.check_circle_outline_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.receipt_long_rounded,
                        color: Colors.white, size: 14),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap:
                canEdit && !_isSaving ? () => _editPaymentAmount(index) : null,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  payment.amount,
                  style: KineticTypography.titleMd.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18),
                ),
                if (canEdit && !_isSaving) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.edit_outlined,
                      color: Colors.white70, size: 13),
                ],
              ],
            ),
          ),
          Text(
            payment.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4)),
            child: Text(
              payment.dueDate,
              style: const TextStyle(
                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: 6),
            Text(
              isPaid
                  ? 'Tap ✕ to mark unpaid · ₱ to edit amount'
                  : 'Tap ✓ to mark paid · 📅 date · ₱ to edit amount',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEncouragementCard(int completed, int total) {
    final remaining = total - completed;
    return Container(
      padding: const EdgeInsets.all(KineticSpacing.md),
      decoration: BoxDecoration(
        color: KineticColors.neonTeal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KineticRadii.md),
        border: Border.all(
            color: KineticColors.neonTeal.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
                color: KineticColors.neonTeal, shape: BoxShape.circle),
            child: const Icon(Icons.emoji_events_rounded,
                color: KineticColors.deepSlate, size: 24),
          ),
          const SizedBox(width: KineticSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  remaining == 0
                      ? '🎉 Cycle ${_activeCycle.cycleNumber} Complete! Superstar!'
                      : '⚡ $remaining more sessions to finish Cycle ${_activeCycle.cycleNumber}!',
                  style: KineticTypography.titleMd.copyWith(
                      color: KineticColors.deepSlate,
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.isTrainerView
                      ? 'Tap session circles to toggle completion. Long-press to edit label.'
                      : 'Keep practicing! Consistency creates champions.',
                  style: KineticTypography.bodySm.copyWith(
                      color: KineticColors.outline, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

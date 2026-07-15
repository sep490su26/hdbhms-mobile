import 'package:flutter/material.dart';
import 'package:hdbhms_mobile/models/contract/lease_contract_model.dart';
import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/services/contract/lease_contract_service.dart';
import 'package:hdbhms_mobile/services/room_transfer/room_transfer_service.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/utils/currency_formatter.dart';
import 'package:hdbhms_mobile/widgets/app_screen_shell.dart';

class CreateRoomTransferScreen extends StatefulWidget {
  const CreateRoomTransferScreen({
    super.key,
    this.preloadedContractId,
    this.transferService = const RoomTransferService(),
    this.contractService = const LeaseContractService(),
  });

  /// If provided, skips the "getMyActiveContract" call and loads this contract
  /// directly.
  final int? preloadedContractId;
  final RoomTransferService transferService;
  final LeaseContractService contractService;

  @override
  State<CreateRoomTransferScreen> createState() =>
      _CreateRoomTransferScreenState();
}

class _CreateRoomTransferScreenState extends State<CreateRoomTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();

  LeaseContract? _currentContract;
  AvailableRoom? _selectedTargetRoom;
  DateTime? _selectedDate;
  bool _loadingContract = true;
  bool _loadingRooms = false;
  bool _submitting = false;
  String? _errorMessage;

  List<AvailableRoom> _availableRooms = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentContract();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentContract() async {
    setState(() {
      _loadingContract = true;
      _errorMessage = null;
    });
    try {
      final LeaseContract contract;
      final id = widget.preloadedContractId;
      if (id != null) {
        // Use the preloaded contract ID (from LeaseContractScreen)
        contract = await widget.contractService.getContractById(id);
      } else {
        // Fallback: get the active contract
        contract = await widget.contractService.getMyActiveContract();
      }
      if (!mounted) return;
      setState(() {
        _currentContract = contract;
        _loadingContract = false;
      });
      // Now load available rooms using the property from the contract
      await _loadAvailableRooms(contract);
    } on LeaseContractNotFoundException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Bạn chưa có hợp đồng thuê phòng đang hiệu lực.';
        _loadingContract = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loadingContract = false;
      });
    }
  }

  Future<void> _loadAvailableRooms(LeaseContract contract) async {
    setState(() => _loadingRooms = true);
    try {
      // We need the property ID from the current room.
      // The backend rooms endpoint needs propertyId.
      // For now, try loading rooms without property filter and let the user pick.
      final rooms = await widget.transferService.fetchAvailableRooms(
        propertyId: 1, // Default property ID; will be improved with real data
        page: 0,
        size: 100,
      );
      if (!mounted) return;
      setState(() {
        _availableRooms = rooms
            .where(
              (r) =>
                  r.currentStatus == 'VACANT' ||
                  r.currentStatus == 'SOON_VACANT' ||
                  r.currentStatus == 'OCCUPIED',
            )
            .toList(growable: false);
        _loadingRooms = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _availableRooms = [];
        _loadingRooms = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentContract == null) {
      _snack('Không tìm thấy hợp đồng hiện tại.');
      return;
    }
    if (_selectedTargetRoom == null) {
      _snack('Vui lòng chọn phòng đích.');
      return;
    }
    if (_selectedDate == null) {
      _snack('Vui lòng chọn ngày chuyển dự kiến.');
      return;
    }

    setState(() => _submitting = true);

    try {
      await widget.transferService.createTransferRequest(
        sourceContractId: _currentContract!.id ?? 0,
        targetRoomId: _selectedTargetRoom!.id,
        requestedTransferDate: _selectedDate!,
        reason: _reasonCtrl.text.trim().isNotEmpty
            ? _reasonCtrl.text.trim()
            : null,
      );

      if (!mounted) return;
      _showSuccessDialog();
    } on RoomTransferException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (e) {
      if (!mounted) return;
      _snack('Không thể tạo yêu cầu chuyển phòng. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _TransferSuccessDialog(
        targetRoomName: _selectedTargetRoom?.displayName ?? '',
        onDone: () {
          Navigator.of(context).pop(); // close dialog
          Navigator.of(context).pop(); // pop this screen
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AppScreenShell(header: _buildHeader(), child: _buildBody()),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: AppColors.topBarHeight,
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.cardBorder.withValues(alpha: 0.65),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.deepBlue,
              size: 24,
            ),
            tooltip: 'Trở về',
          ),
          const Expanded(
            child: Text('Chuyển phòng', style: AppColors.topBarTitleStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingContract) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.deepBlue),
      );
    }

    if (_errorMessage != null) {
      return _ErrorState(
        message: _errorMessage!,
        onRetry: _loadCurrentContract,
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
        children: [
          // ── Source contract info ────────────────────────────────────────
          _SectionCard(
            title: 'Hợp đồng hiện tại',
            icon: Icons.home_work_outlined,
            children: [
              _InfoRow(
                label: 'Mã hợp đồng',
                value: _currentContract?.contractCode ?? '--',
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0xFFEEECEE)),
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Phòng hiện tại',
                value:
                    _currentContract?.room.roomName ??
                    _currentContract?.room.roomCode ??
                    '--',
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Target room picker ──────────────────────────────────────────
          _SectionCard(
            title: 'Phòng đích',
            icon: Icons.swap_horiz_rounded,
            children: [
              if (_loadingRooms)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.deepBlue,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else
                _RoomPickerField(
                  selectedRoom: _selectedTargetRoom,
                  rooms: _availableRooms,
                  currentRoomCode: _currentContract?.room.roomCode ?? '',
                  onChanged: (room) =>
                      setState(() => _selectedTargetRoom = room),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Transfer date ───────────────────────────────────────────────
          _SectionCard(
            title: 'Ngày chuyển dự kiến',
            icon: Icons.calendar_month_outlined,
            children: [
              _DateField(
                selectedDate: _selectedDate,
                onPick: _pickDate,
                format: _formatDate,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Reason ──────────────────────────────────────────────────────
          _SectionCard(
            title: 'Lý do chuyển phòng',
            icon: Icons.notes_outlined,
            children: [
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                enableSuggestions: true,
                autocorrect: true,
                decoration: const InputDecoration(
                  hintText: 'Nhập lý do chuyển phòng (không bắt buộc)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(
                  color: AppColors.inputText,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Submit button ───────────────────────────────────────────────
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.deepBlue.withValues(
                  alpha: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Gửi yêu cầu chuyển phòng',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.deepBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF000666),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.bodyText,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppColors.inputText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomPickerField extends StatefulWidget {
  const _RoomPickerField({
    required this.selectedRoom,
    required this.rooms,
    required this.currentRoomCode,
    required this.onChanged,
  });

  final AvailableRoom? selectedRoom;
  final List<AvailableRoom> rooms;
  final String currentRoomCode;
  final ValueChanged<AvailableRoom?> onChanged;

  @override
  State<_RoomPickerField> createState() => _RoomPickerFieldState();
}

class _RoomPickerFieldState extends State<_RoomPickerField> {
  String _search = '';

  List<AvailableRoom> get _filtered {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return widget.rooms;
    return widget.rooms.where((r) {
      return r.roomCode.toLowerCase().contains(query) ||
          r.roomName.toLowerCase().contains(query) ||
          r.propertyName.toLowerCase().contains(query) ||
          r.floorName.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search box
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: const InputDecoration(
            hintText: 'Tìm phòng theo mã, tên...',
            prefixIcon: Icon(Icons.search, color: AppColors.hintText),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide(color: AppColors.border),
            ),
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          style: const TextStyle(color: AppColors.inputText, fontSize: 14),
        ),

        const SizedBox(height: 10),

        // Selected room display
        if (widget.selectedRoom != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedRoom!.displayName,
                        style: const TextStyle(
                          color: AppColors.inputText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${widget.selectedRoom!.propertyName} - ${widget.selectedRoom!.floorName}',
                        style: const TextStyle(
                          color: AppColors.bodyText,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Giá: ${CurrencyFormatter.vnd(widget.selectedRoom!.listedPrice.toDouble())}/tháng',
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.bodyText,
                    size: 18,
                  ),
                  onPressed: () => widget.onChanged(null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Room list
        if (_filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                'Không tìm thấy phòng phù hợp',
                style: TextStyle(color: AppColors.bodyText, fontSize: 13),
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _filtered.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFEEECEE)),
              itemBuilder: (context, index) {
                final room = _filtered[index];
                final isCurrent = room.roomCode == widget.currentRoomCode;
                final isSelected = widget.selectedRoom?.id == room.id;

                return ListTile(
                  dense: true,
                  enabled: !isCurrent,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isCurrent ? Icons.block : Icons.meeting_room_outlined,
                    color: isCurrent ? AppColors.bodyText : AppColors.deepBlue,
                    size: 22,
                  ),
                  title: Text(
                    room.displayName,
                    style: TextStyle(
                      color: isCurrent
                          ? AppColors.bodyText
                          : AppColors.inputText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    isCurrent
                        ? '(Phòng hiện tại)'
                        : '${room.propertyName} - ${room.floorName}',
                    style: const TextStyle(
                      color: AppColors.bodyText,
                      fontSize: 11,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 18,
                        )
                      : null,
                  onTap: isCurrent ? null : () => widget.onChanged(room),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.selectedDate,
    required this.onPick,
    required this.format,
  });

  final DateTime? selectedDate;
  final VoidCallback onPick;
  final String Function(DateTime) format;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_outlined,
              color: AppColors.hintText,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedDate == null
                    ? 'Chọn ngày chuyển dự kiến'
                    : format(selectedDate!),
                style: TextStyle(
                  color: selectedDate == null
                      ? AppColors.hintText
                      : AppColors.inputText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.hintText,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline,
                color: AppColors.danger,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.inputText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}

class _TransferSuccessDialog extends StatelessWidget {
  const _TransferSuccessDialog({
    required this.targetRoomName,
    required this.onDone,
  });

  final String targetRoomName;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Gửi yêu cầu thành công',
              style: TextStyle(
                color: AppColors.inputText,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yêu cầu chuyển sang $targetRoomName đã được gửi.\nQuản lý sẽ duyệt trong thời gian sớm nhất.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.bodyText,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Đã hiểu',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

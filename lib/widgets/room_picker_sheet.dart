import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/models/room_transfer/room_transfer_model.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';
import 'package:hdbhms_mobile/theme/app_typography.dart';
import 'package:hdbhms_mobile/utils/currency_formatter.dart';
import 'package:hdbhms_mobile/widgets/app_filter_chip.dart';
import 'package:hdbhms_mobile/widgets/app_primary_gradient_button.dart';

class RoomPickerSheet extends StatefulWidget {
  const RoomPickerSheet({
    super.key,
    required this.rooms,
    required this.currentRoomId,
    this.initialSelection,
  });

  final List<AvailableRoom> rooms;
  final int? currentRoomId;
  final AvailableRoom? initialSelection;

  @override
  State<RoomPickerSheet> createState() => _RoomPickerSheetState();
}

class _RoomPickerSheetState extends State<RoomPickerSheet> {
  final _searchController = TextEditingController();
  String _filter = 'ALL';
  AvailableRoom? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AvailableRoom> get _filtered => widget.rooms
      .where((room) {
        if (_filter != 'ALL' && room.currentStatus != _filter) return false;
        final query = _searchController.text.trim().toLowerCase();
        return query.isEmpty ||
            room.displayName.toLowerCase().contains(query) ||
            room.roomCode.toLowerCase().contains(query);
      })
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final rooms = _filtered;
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        initialChildSize: .9,
        minChildSize: .65,
        maxChildSize: .96,
        expand: false,
        builder: (context, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Chọn phòng',
                        style: AppTypography.sectionTitle,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: AppColors.inputFill,
                    hintText: 'Tìm theo mã hoặc tên phòng...',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.bodyText,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _FilterChip(
                      label: 'Tất cả',
                      selected: _filter == 'ALL',
                      onTap: () => setState(() => _filter = 'ALL'),
                    ),
                    _FilterChip(
                      label: 'Còn trống',
                      selected: _filter == 'VACANT',
                      onTap: () => setState(() => _filter = 'VACANT'),
                    ),
                    _FilterChip(
                      label: 'Sắp trống',
                      selected: _filter == 'SOON_VACANT',
                      onTap: () => setState(() => _filter = 'SOON_VACANT'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: rooms.isEmpty
                    ? _EmptyRooms(
                        onClear: () {
                          _searchController.clear();
                          setState(() => _filter = 'ALL');
                        },
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: rooms.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          final room = rooms[index];
                          final isCurrent = room.id == widget.currentRoomId;
                          return _RoomOptionCard(
                            room: room,
                            selected: _selected?.id == room.id,
                            isCurrent: isCurrent,
                            onTap: isCurrent
                                ? null
                                : () => setState(() => _selected = room),
                          );
                        },
                      ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.cardBorder.withValues(alpha: .52),
                    ),
                  ),
                ),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  12 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: AppPrimaryGradientButton(
                    height: 52,
                    onPressed: _selected == null
                        ? null
                        : () => Navigator.of(context).pop(_selected),
                    child: const Text('Chọn phòng này'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      AppFilterChip(label: label, isActive: selected, onTap: onTap);
}

class _RoomOptionCard extends StatelessWidget {
  const _RoomOptionCard({
    required this.room,
    required this.selected,
    required this.isCurrent,
    this.onTap,
  });
  final AvailableRoom room;
  final bool selected;
  final bool isCurrent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: !isCurrent,
    label: '${room.displayName}, ${room.statusLabel}',
    child: Material(
      color: selected ? AppColors.primarySurface : AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Opacity(
          opacity: isCurrent ? .72 : 1,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.cardBorder,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              room.displayName,
                              style: AppTypography.cardTitle,
                            ),
                          ),
                          _RoomStatusBadge(
                            label: isCurrent
                                ? 'Phòng hiện tại'
                                : room.statusLabel,
                            muted: isCurrent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _metadata(room),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${CurrencyFormatter.vnd(room.listedPrice)} / tháng',
                              style: AppTypography.metaValue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tối đa ${room.maxOccupants} người',
                            maxLines: 1,
                            style: AppTypography.metaLabel,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.primary : AppColors.bodyText,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String _metadata(AvailableRoom room) => [
  if (room.propertyName.isNotEmpty) room.propertyName,
  if (room.floorName.isNotEmpty) room.floorName,
  if (room.areaM2 != null) '${room.areaM2} m²',
].join(' · ');

class _RoomStatusBadge extends StatelessWidget {
  const _RoomStatusBadge({required this.label, required this.muted});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: muted ? AppColors.surfaceMuted : AppColors.successSurface,
      borderRadius: BorderRadius.circular(AppColors.radiusPill),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.metaLabel.copyWith(
        color: muted ? AppColors.bodyText : AppColors.successText,
      ),
    ),
  );
}

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms({required this.onClear});
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 36,
            color: AppColors.bodyText,
          ),
          const SizedBox(height: 12),
          const Text(
            'Không tìm thấy phòng phù hợp',
            style: AppTypography.cardTitle,
          ),
          const SizedBox(height: 4),
          const Text(
            'Thử từ khóa khác hoặc xóa bộ lọc.',
            textAlign: TextAlign.center,
            style: AppTypography.body,
          ),
          TextButton(onPressed: onClear, child: const Text('Xóa tìm kiếm')),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import 'package:hdbhms_mobile/screens/home/home_screen.dart';
import 'package:hdbhms_mobile/theme/app_colors.dart';

/// Local-only preview of the exact Home error state shown once access to a
/// liquidated room has ended. It deliberately makes no service call.
class PostLiquidationHomeAccessPreviewScreen extends StatelessWidget {
  const PostLiquidationHomeAccessPreviewScreen({super.key});

  static const _accessEndedMessage =
      'Bạn không còn quyền truy cập P.203 vì hợp đồng thuê đã kết thúc.';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: HomeAccessErrorState(
        title: 'P.203',
        message: _accessEndedMessage,
        onRetry: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đây là trạng thái xem trước sau thanh lý phòng.'),
          ),
        ),
        onOpenRoomOverview: () => Navigator.of(context).maybePop(),
      ),
    ),
  );
}

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// 파일 끌어놓기는 웹/PC에서만 켜고, 안드로이드·iOS에서는 child만 그대로 돌려준다
class PlatformDropTarget extends StatelessWidget {
  const PlatformDropTarget({
    super.key,
    required this.child,
    this.onDragEntered,
    this.onDragExited,
    this.onDragDone,
  });

  final Widget child;
  final void Function(DropEventDetails)? onDragEntered;
  final void Function(DropEventDetails)? onDragExited;
  final void Function(DropDoneDetails)? onDragDone;

  // 모바일(안드로이드·iOS)인지 여부, 웹은 모바일 브라우저여도 끌어놓기 허용
  static bool get _isMobile =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    if (_isMobile) return child;
    return DropTarget(
      onDragEntered: onDragEntered,
      onDragExited: onDragExited,
      onDragDone: onDragDone,
      child: child,
    );
  }
}

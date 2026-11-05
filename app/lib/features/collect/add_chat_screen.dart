import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/platform_drop_target.dart';
import '../../core/app_text.dart';
import '../../domain/models/chat_preview.dart';
import '../../domain/repositories/chatroom_repository.dart';
import 'collect_data.dart';
import 'widgets/next_button.dart';
import 'widgets/person_avatar.dart';
import 'widgets/sub_screen_scaffold.dart';

// 대화방 추가 화면: 대화 파일을 읽어 미리 보여 주고, 표시 이름을 정해 추가한다
class AddChatScreen extends StatefulWidget {
  const AddChatScreen({super.key, this.initial, this.existing});

  // 이미 추가한 대화방을 고치러 들어온 경우 그 값 (있으면 선택창 없이 현재 내용을 보여 준다)
  final PickedChat? existing;

  // 끌어다 놓아서 들어온 파일 (있으면 선택창 없이 바로 읽는다)
  final DroppedFile? initial;

  @override
  State<AddChatScreen> createState() => _AddChatScreenState();
}

class _AddChatScreenState extends State<AddChatScreen> {
  // 지금 읽은 파일의 미리보기 (아직 고르기 전이면 null)
  ChatPreview? _preview;
  // 서버 연결·읽기 오류 문구 (없으면 null)
  String? _error;
  // 파일을 읽는 중인지
  bool _reading = false;
  // 앱에 표시할 이름 입력칸
  final TextEditingController _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 끌어다 놓은 파일이 있으면 바로 읽고, 없으면 파일 선택창을 띄운다
    final init = widget.initial;
    final old = widget.existing;
    if (old != null) {
      _preview = old.preview;
      _name.text = old.displayName;
    } else if (init != null) {
      _load(init.name, init.bytes);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick(firstTime: true));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  // 파일 선택창을 열어 .txt를 읽고 미리보기를 만든다 (처음 취소하면 화면을 닫는다)
  Future<void> _pick({bool firstTime = false}) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );
    if (file == null) {
      if (firstTime && mounted) Navigator.pop(context);
      return;
    }
    await _load(file.name, await file.readAsBytes());
  }

  // 파일 내용을 서버에 보내 미리보기를 받고 화면에 반영한다 (서버 연결이 안 되면 오류 문구를 보인다)
  Future<void> _load(String name, List<int> bytes) async {
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final preview = await context.read<ChatroomRepository>().previewMessenger(
            content: utf8.decode(bytes, allowMalformed: true),
            fileName: name,
            sizeBytes: bytes.length,
          );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _name.text = preview.suggestedName;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '서버에서 대화를 읽지 못했어요. 서버가 켜져 있는지 확인해 주세요.\n($e)');
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  // 화면 위로 파일을 끌어다 놓으면 그 .txt로 바꿔 읽는다
  Future<void> _onDrop(List<dynamic> files) async {
    if (files.isEmpty) return;
    final f = files.first;
    if (!(f.name as String).toLowerCase().endsWith('.txt')) return;
    await _load(f.name as String, await f.readAsBytes());
  }

  // 이름이 비어 있지 않을 때만 추가할 수 있다
  bool get _canAdd => (_preview?.ok ?? false) && _name.text.trim().isNotEmpty;

  // 삭제 여부를 한 번 더 물어보고, 확인하면 '삭제' 신호를 들고 이전 화면으로 돌아간다
  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 대화방을 삭제할까요?'),
        content: const Text('목록에서만 빠지고, 원본 파일은 그대로예요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context, kDeleteChat);
  }

  // 확정한 값을 들고 이전 화면으로 돌아간다
  void _confirm() {
    Navigator.pop(context, PickedChat(preview: _preview!, displayName: _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return PlatformDropTarget(
      onDragDone: (d) => _onDrop(d.files),
      child: SubScreenScaffold(
      title: widget.existing == null ? '대화방 추가' : '대화방 수정',
      body: p == null
          ? Center(
              child: _reading
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error ?? '파일을 선택해 주세요',
                        textAlign: TextAlign.center,
                        style: appText(13, color: _error == null ? AppColors.textSecondary : const Color(0xFFD64545)),
                      ),
                    ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FileCard(preview: p, onChange: _pick),
                  const SizedBox(height: 14),
                  Text('이 대화방을 이렇게 가져와요', style: appText(14, weight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (!p.ok) _buildError() else _buildPreview(p),
                ],
              ),
            ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.existing != null)
            TextButton(
              onPressed: _delete,
              child: Text('이 대화방 삭제', style: appText(13, weight: FontWeight.w700, color: const Color(0xFFD64545))),
            ),
          NextButton(label: widget.existing == null ? '이 대화방 추가하기' : '수정 완료', enabled: _canAdd, onPressed: _confirm),
        ],
      ),
      ),
    );
  }

  // 읽기에 실패했을 때 보여 주는 안내 카드
  Widget _buildError() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Text(
        '대화를 읽지 못했어요. 카카오톡에서 내보낸 대화 파일(.txt)인지 확인하고 "변경"으로 다시 골라 주세요.',
        style: appText(12.5, color: const Color(0xFFD64545)),
      ),
    );
  }

  // 표시 이름 입력, 참여자, 기간, 메시지 수를 보여 주는 미리보기 카드와 안내 문구
  Widget _buildPreview(ChatPreview p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('앱에 표시할 이름', style: appText(11, weight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                style: appText(14, weight: FontWeight.w700),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDDE3F7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('참여자', style: appText(11, weight: FontWeight.w700, color: AppColors.textSecondary)),
                  Text('${p.participants.length}명', style: appText(11, weight: FontWeight.w700, color: AppColors.accent)),
                ],
              ),
              const SizedBox(height: 10),
              // 6명을 넘으면 가로로 스크롤한다
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: p.participants.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => SizedBox(
                    width: 48,
                    child: Column(
                      children: [
                        PersonAvatar(index: i, size: 44),
                        const SizedBox(height: 6),
                        Text(
                          p.participants[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appText(10.5, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 24, color: Color(0xFFE6EAF6)),
              _InfoRow(
                label: '기간',
                value: '${formatDate(p.start!)} – ${formatShortDate(p.end!)}',
              ),
              const SizedBox(height: 12),
              _InfoRow(label: '메시지', value: '${formatCount(p.messageCount)}개'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.tileBg, shape: BoxShape.circle),
              child: Text('i', style: appText(11, weight: FontWeight.w700, color: AppColors.accent)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '참여자 이름은 사진 이름 입력 때 자동완성으로 쓰여요',
                style: appText(11.5, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// 위쪽 파일 카드 (파일 이름, 크기와 읽기 상태, '변경' 버튼)
class _FileCard extends StatelessWidget {
  const _FileCard({required this.preview, required this.onChange});

  final ChatPreview preview;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppColors.tileBg, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.notes_rounded, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(preview.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: appText(13.5, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${formatSize(preview.sizeBytes)} · ${preview.ok ? '읽기 완료' : '읽기 실패'}',
                  style: appText(11, color: preview.ok ? AppColors.textSecondary : const Color(0xFFD64545)),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.tileBg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onChange,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Text('변경', style: appText(11.5, weight: FontWeight.w700, color: AppColors.accent)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// '기간 ... 값'처럼 왼쪽 이름표와 오른쪽 값을 한 줄로 보여 주는 행
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: appText(11, weight: FontWeight.w700, color: AppColors.textSecondary)),
        Text(value, style: appText(12.5, weight: FontWeight.w700)),
      ],
    );
  }
}

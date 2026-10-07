import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/user_service.dart' show currentUsername;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/character.dart';
import '../widgets/entrance.dart';

/// "Ask Ethmar": the bot says hello, and the user can type messages.
///
/// UI only for now: messages stay on this screen and the bot doesn't reply.
/// TODO(chatbot): Send the user's messages to the chatbot and show its
///   replies.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.username = ''});
  final String username;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// What the user has sent, oldest first.
  final _sent = <String>[];

  @override
  void initState() {
    super.initState();
    // Rebuild so the send button turns on and off with the text.
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sent.add(text));
    _input.clear();
    // Scroll to the new message once it's laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final savedName = currentUsername.value;
    final name = savedName.isNotEmpty
        ? savedName
        : widget.username.isNotEmpty
        ? widget.username
        : s.homeFriend;
    return Scaffold(
      body: LeafPrintBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ChatHeader(title: s.chatTitle),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                children: [
                  Entrance(
                    delay: const Duration(milliseconds: 200),
                    child: _Bubble(text: s.chatGreeting(name), fromUser: false),
                  ),
                  for (var i = 0; i < _sent.length; i++)
                    Entrance(
                      key: ValueKey(i),
                      offset: 8,
                      child: _Bubble(text: _sent[i], fromUser: true),
                    ),
                ],
              ),
            ),
            _InputBar(
              controller: _input,
              hint: s.chatHint,
              sendLabel: s.chatSend,
              onSend: _input.text.trim().isEmpty ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft green header with rounded bottom corners: back, the title, and the
/// waving Ethmar buddy.
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        12,
        12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.forestTint,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          Material(
            color: AppColors.surface,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: S.of(context).back,
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.forest,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: AppText.title(context).copyWith(fontSize: 22),
            ),
          ),
          const SizedBox(width: 8),
          const EthmarCharacter(name: 'ethmar_buddy_waving', height: 96),
        ],
      ),
    );
  }
}

/// One message. Ethmar's sit at the start in soft green, the user's at the
/// end in forest (sides flip in Arabic).
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.fromUser});
  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(20);
    const tail = Radius.circular(6);
    return Align(
      alignment: fromUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: fromUser ? AppColors.forest : AppColors.forestTint,
            borderRadius: BorderRadiusDirectional.only(
              topStart: r,
              topEnd: r,
              bottomStart: fromUser ? r : tail,
              bottomEnd: fromUser ? tail : r,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.forest.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            text,
            style: AppText.label(
              context,
              color: fromUser ? AppColors.onForest : AppColors.forest,
            ).copyWith(fontSize: 15, height: 1.4),
          ),
        ),
      ),
    );
  }
}

/// White pill text field and the round send button.
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.hint,
    required this.sendLabel,
    required this.onSend,
  });
  final TextEditingController controller;
  final String hint;
  final String sendLabel;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    const pill = BorderRadius.all(Radius.circular(28));
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend?.call(),
                style: AppText.body(
                  context,
                  color: AppColors.forest,
                ).copyWith(fontSize: 15),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: AppText.body(context),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsetsDirectional.fromSTEB(
                    20,
                    14,
                    16,
                    14,
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: pill,
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: pill,
                    borderSide: BorderSide(color: AppColors.forest, width: 1.6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: sendLabel,
              onPressed: onSend,
              style: IconButton.styleFrom(
                minimumSize: const Size(52, 52),
                backgroundColor: AppColors.coralTint,
                foregroundColor: AppColors.forest,
                disabledBackgroundColor: AppColors.coralTint.withValues(
                  alpha: 0.5,
                ),
                disabledForegroundColor: AppColors.textHint,
              ),
              // send_rounded points the other way in Arabic.
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

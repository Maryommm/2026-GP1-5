import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../services/user_service.dart' show currentUsername;
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/backgrounds.dart';
import '../widgets/entrance.dart';

/// The "Ask Thamoor" chat screen.
/// For now it is UI only: messages stay on this screen and the bot doesn't
/// reply.
/// TODO(chatbot): in the next sprints.

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
    // The send button turns on and off depending on the text.
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
    // Scroll to the new message after it's drawn.
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

/// The header of the Ask Thamoor tab (a main tab, so no back button): the
/// name of who you're talking to, centred like in a chat app.
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.title});
  final String title;

  /// Height below the status bar (the same in both languages).
  static const height = 74.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('chatHeader'),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top,
        16,
        0,
      ),
      decoration: const BoxDecoration(
        color: AppColors.featureCard,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SizedBox(
        height: height,
        child: Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: AppText.title(context).copyWith(fontSize: 22),
          ),
        ),
      ),
    );
  }
}

/// Thamoor's picture next to his messages: a round crop of his face from
/// the waving character, like a chat profile picture.
class _ThamoorAvatar extends StatelessWidget {
  const _ThamoorAvatar();

  static const size = 38.0;

  // ethmar_buddy_waving.png is 454 x 614. The circle shows a 290 x 290
  // square of it centred on (228, 240), which is the face under the hat.
  static const _imageWidth = 454.0;
  static const _imageHeight = 614.0;
  static const _shown = 290.0;
  static const _centreX = 228.0;
  static const _centreY = 240.0;

  @override
  Widget build(BuildContext context) {
    const k = size / _shown;
    return ExcludeSemantics(
      child: ClipOval(
        key: const Key('thamoorAvatar'),
        child: Container(
          width: size,
          height: size,
          color: AppColors.surface,
          child: Stack(
            children: [
              Positioned(
                left: size / 2 - _centreX * k,
                top: size / 2 - _centreY * k,
                width: _imageWidth * k,
                height: _imageHeight * k,
                child: Image.asset(
                  'assets/images/ethmar_buddy_waving.png',
                  fit: BoxFit.fill, // Same aspect ratio, so it isn't stretched.
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One message. Thamoor's messages are on the start side next to his
/// picture; the user's are on the end side.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.fromUser});
  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      child: _face(context),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: fromUser
          ? Align(alignment: AlignmentDirectional.centerEnd, child: bubble)
          // The picture is at the bubble's bottom corner, like in chat apps. The Row
          // puts it on the start side in both languages.
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const _ThamoorAvatar(),
                const SizedBox(width: 8),
                Flexible(child: bubble),
              ],
            ),
    );
  }

  Widget _face(BuildContext context) {
    const r = Radius.circular(20);
    const tail = Radius.circular(6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: fromUser ? AppColors.forest : AppColors.featureCard,
        borderRadius: BorderRadiusDirectional.only(
          topStart: r,
          topEnd: r,
          bottomStart: fromUser ? r : tail,
          bottomEnd: fromUser ? tail : r,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: AppText.label(
          context,
          color: fromUser ? AppColors.onForest : AppColors.textPrimary,
        ).copyWith(fontSize: 14, height: 1.5),
      ),
    );
  }
}

/// The message text field and the send button.
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
        // The button stays level with the field's last line when the message has
        // several lines.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              // No hint text on screen, but screen readers still say what the field is
              // for.
              child: Semantics(
                label: hint,
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend?.call(),
                  style: AppText.body(
                    context,
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 15),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: EdgeInsetsDirectional.fromSTEB(
                      20,
                      14,
                      16,
                      14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: pill,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: pill,
                      borderSide: BorderSide(color: AppColors.forest, width: 1.6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: sendLabel,
              onPressed: onSend,
              style: IconButton.styleFrom(
                // The same height as a one-line field, so they line up.
                fixedSize: const Size(52, 52),
                minimumSize: const Size(52, 52),
                // The same white and border as the message field.
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.forest,
                disabledBackgroundColor: AppColors.surface,
                disabledForegroundColor: AppColors.forest.withValues(
                  alpha: 0.35,
                ),
                side: const BorderSide(color: AppColors.border),
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

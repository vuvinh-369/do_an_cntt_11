// File: lib/views/userview/chatbox_ai_view.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_models.dart';
import '../viewmodels/user_viewmodel.dart';
import 'widgets/user_painters.dart';

class ChatBoxAiView extends StatelessWidget {
  const ChatBoxAiView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    final screenSize = MediaQuery.sizeOf(context);
    final isMobile = screenSize.width < 768;

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: viewModel.chatMessages.isEmpty
                  ? _buildEmptyChatWelcomeState(
                      context,
                      viewModel,
                      isMobile: true,
                    )
                  : ListView.separated(
                      controller: viewModel.chatScrollController,
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      itemCount: viewModel.chatMessages.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final message = viewModel.chatMessages[index];
                        return message.isUser
                            ? _buildUserChatMessageRow(message, isMobile: true)
                            : _buildAiChatMessageRow(
                                context,
                                message,
                                isMobile: true,
                              );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            _buildChatBottomInputBar(context, viewModel, isMobile: true),
          ],
        ),
      );
    }

    // =========================================================================
    // GIAO DIỆN PC / DESKTOP (GIỮ NGUYÊN 100%)
    // =========================================================================
    final double fixedChatViewportHeight = math.max(
      540.0,
      screenSize.height - 135,
    );

    return SizedBox(
      height: fixedChatViewportHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ChatBox AI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D2B6B),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hỏi đáp nhanh về các tình huống sơ cứu',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: viewModel.chatMessages.isEmpty
                  ? _buildEmptyChatWelcomeState(context, viewModel)
                  : Scrollbar(
                      controller: viewModel.chatScrollController,
                      thumbVisibility: true,
                      child: ListView.separated(
                        controller: viewModel.chatScrollController,
                        padding: const EdgeInsets.only(
                          top: 4,
                          bottom: 16,
                          right: 8,
                        ),
                        itemCount: viewModel.chatMessages.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 22),
                        itemBuilder: (context, index) {
                          final message = viewModel.chatMessages[index];
                          return message.isUser
                              ? _buildUserChatMessageRow(message)
                              : _buildAiChatMessageRow(context, message);
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            _buildChatBottomInputBar(context, viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChatWelcomeState(
    BuildContext context,
    UserViewModel viewModel, {
    bool isMobile = false,
  }) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isMobile ? 48 : 56,
              height: isMobile ? 48 : 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                color: const Color(0xFF2563EB),
                size: isMobile ? 24 : 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bắt đầu cuộc trò chuyện với Trợ lý Cứu hộ AI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? 15 : 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D2B6B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Nhập câu hỏi của bạn vào ô bên dưới hoặc chọn nhanh một tình huống gợi ý:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: viewModel.quickSuggestedQuestions.map((question) {
                return ActionChip(
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: Color(0xFFDBEAFE)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  label: Text(
                    question,
                    style: TextStyle(
                      fontSize: isMobile ? 12.5 : 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  onPressed: () =>
                      context.read<UserViewModel>().sendChatMessage(question),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserChatMessageRow(
    ChatMessageModel message, {
    bool isMobile = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: isMobile ? 280 : 460),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 18,
                  vertical: isMobile ? 11 : 13,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFDCEBFE),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  message.messageText,
                  style: TextStyle(
                    fontSize: isMobile ? 13.5 : 14.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D2B6B),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  message.timestamp,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: const CustomPaint(painter: ChatUserPortraitAvatarPainter()),
          ),
        ],
      ],
    );
  }

  Widget _buildAiChatMessageRow(
    BuildContext context,
    ChatMessageModel message, {
    bool isMobile = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: isMobile ? 34 : 40,
          height: isMobile ? 34 : 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF93C5FD).withValues(alpha: 0.55),
              width: 2.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F2563EB),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(isMobile ? 7 : 8.5),
          child: const CustomPaint(painter: AiShieldBadgePainter()),
        ),
        SizedBox(width: isMobile ? 10 : 12),
        Flexible(
          child: Container(
            constraints: BoxConstraints(maxWidth: isMobile ? 310 : 560),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 15 : 20,
              vertical: isMobile ? 14 : 18,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.messageText,
                  style: TextStyle(
                    fontSize: isMobile ? 13.5 : 14.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1E293B),
                    height: 1.45,
                  ),
                ),
                if (message.numberedSteps.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...List.generate(message.numberedSteps.length, (index) {
                    final stepNumber = index + 1;
                    final stepContent = message.numberedSteps[index];
                    final isLastStep =
                        index == message.numberedSteps.length - 1;

                    return Padding(
                      padding: EdgeInsets.only(bottom: isLastStep ? 0 : 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 20,
                            child: Text(
                              '$stepNumber.',
                              style: TextStyle(
                                fontSize: isMobile ? 13.5 : 14.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E293B),
                                height: 1.4,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              stepContent,
                              style: TextStyle(
                                fontSize: isMobile ? 13.5 : 14.5,
                                fontWeight: FontWeight.w400,
                                color: const Color(0xFF1E293B),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 8),
                Text(
                  message.timestamp,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatBottomInputBar(
    BuildContext context,
    UserViewModel viewModel, {
    bool isMobile = false,
  }) {
    return Container(
      height: isMobile ? 48 : 54,
      padding: EdgeInsets.only(left: isMobile ? 16 : 20, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060D2B6B),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: viewModel.chatInputController,
              onChanged: (value) =>
                  context.read<UserViewModel>().updateChatInput(value),
              onSubmitted: (value) =>
                  context.read<UserViewModel>().sendChatMessage(value),
              style: TextStyle(
                fontSize: isMobile ? 13.5 : 14.5,
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Nhập câu hỏi của bạn...',
                hintStyle: TextStyle(
                  fontSize: isMobile ? 13.5 : 14.5,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFF2563EB),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.read<UserViewModel>().sendChatMessage(),
              child: SizedBox(
                width: isMobile ? 36 : 40,
                height: isMobile ? 36 : 40,
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 8.5 : 10),
                  child: const CustomPaint(
                    painter: PaperPlaneSendIconPainter(),
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

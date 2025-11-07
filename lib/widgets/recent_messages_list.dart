import 'package:flutter/material.dart';
import '../models/recent_message.dart';
import '../constants/theme.dart';
import 'package:timeago/timeago.dart' as timeago;

class RecentMessagesList extends StatelessWidget {
  final List<RecentMessage> messages;
  final Function(RecentMessage) onTap;

  const RecentMessagesList({
    Key? key,
    required this.messages,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageTile(message);
      },
    );
  }

  Widget _buildMessageTile(RecentMessage message) {
    return InkWell(
      onTap: () => onTap(message),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            _buildAvatar(message),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                        message.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF11403a),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Text(
                        timeago.format(message.updatedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                          ),
                          if ((message.unreadCount ?? 0) > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                message.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.lastMessagePreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(RecentMessage message) {
    // print('Avatar URL: \\${message.avatarUrl}'); // Debugging ke liye
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.secondaryColor.withOpacity(0.1),
        border: Border.all(
          color: AppTheme.secondaryColor.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: message.avatarUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Image.network(
                message.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  print('Image load error: $error'); // Debugging ke liye
                  return Icon(
                    message.conversationType == 'private'
                        ? Icons.person
                        : Icons.group,
                    color: AppTheme.secondaryColor,
                    size: 24,
                  );
                },
              ),
            )
          : Icon(
              message.conversationType == 'private'
                  ? Icons.person
                  : Icons.group,
              color: AppTheme.secondaryColor,
              size: 24,
            ),
    );
  }
} 
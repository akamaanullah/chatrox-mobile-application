class ApiConfig {
  // Base URL for the API
  // Development: http://172.16.32.59:8886
  // Production: https://chatrox.com
  static const String baseUrl = 'http://172.16.32.59:8886';
  static const String apiBaseUrl = '$baseUrl/chatrox-api';
  
  // Auth endpoints
  static const String loginEndpoint = '$apiBaseUrl/auth/login.php';
  static const String logoutEndpoint = '$apiBaseUrl/auth/logout.php';
  static const String changePasswordEndpoint = '$apiBaseUrl/auth/change_password.php';
  
  // User endpoints
  static const String getUserProfileEndpoint = '$apiBaseUrl/users/get_profile.php';
  static const String updateProfileEndpoint = '$apiBaseUrl/users/update_profile.php';
  static const String removeProfileEndpoint = '$apiBaseUrl/users/remove_profile.php';
  static const String editBioEndpoint = '$apiBaseUrl/users/edit_bio.php';
  static const String editNameEndpoint = '$apiBaseUrl/users/edit_name.php';
  static const String getUserDetailsEndpoint = '$apiBaseUrl/users/get_user_details.php';
  
  // Message endpoints
  static const String getRecentMessagesEndpoint = '$apiBaseUrl/messages/get_recent_messages.php';
  static const String getUserMessagesEndpoint = '$apiBaseUrl/messages/get_user_messages.php';
  static const String uploadPrivateFileEndpoint = '$apiBaseUrl/messages/upload_private_file.php';
  static const String sendPrivateMessageEndpoint = '$apiBaseUrl/messages/send_private_message.php';
  static const String addReactionEndpoint = '$apiBaseUrl/messages/add_reaction.php';
  static const String editPrivateMessageEndpoint = '$apiBaseUrl/messages/edit_private_message.php';
  static const String getForwardListEndpoint = '$apiBaseUrl/messages/get_forward_list.php';
  static const String forwardMessageEndpoint = '$apiBaseUrl/messages/forward_message.php';
  static const String deletePrivateMessageEndpoint = '$apiBaseUrl/messages/delete_private_message.php';
  
  // Channel endpoints
  static const String removeMembersEndpoint = '$apiBaseUrl/channels/remove_members.php';
  static const String addMembersEndpoint = '$apiBaseUrl/channels/add_members.php';
  static const String editChannelEndpoint = '$apiBaseUrl/channels/edit.php';
  static const String acceptRequestEndpoint = '$apiBaseUrl/channels/accept_request.php';
  static const String rejectRequestEndpoint = '$apiBaseUrl/channels/reject_request.php';
  
  // Channel message endpoints
  static const String uploadChannelMediaEndpoint = '$apiBaseUrl/channel_messages/upload_media.php';
  static const String sendChannelMessageEndpoint = '$apiBaseUrl/channel_messages/send_message.php';
  static const String replyChannelMessageEndpoint = '$apiBaseUrl/channel_messages/reply_message.php';
  static const String editChannelMessageEndpoint = '$apiBaseUrl/channel_messages/edit_message.php';
  static const String universalForwardEndpoint = '$apiBaseUrl/messages/universal_forward.php';
  
  // Notification endpoints
  static const String getActivitiesEndpoint = '$apiBaseUrl/notifications/get_activities.php';
  static const String markAsReadEndpoint = '$apiBaseUrl/notifications/mark_as_read.php';
  static const String getNotificationsEndpoint = '$apiBaseUrl/notifications/get_notifications.php';
  static const String deleteNotificationEndpoint = '$apiBaseUrl/notifications/delete.php';
  
  // Announcement endpoints
  static const String deleteAnnouncementEndpoint = '$apiBaseUrl/announcements/delete.php';
  
  // Mark read endpoints
  static const String markChannelReadEndpoint = '$apiBaseUrl/messages/mark_channel_read.php';
  static const String markPrivateReadEndpoint = '$apiBaseUrl/messages/mark_private_read.php';
  
  // Helper method to get full URL for assets
  static String getAssetUrl(String path) {
    if (path.startsWith('/')) {
      return '$baseUrl$path';
    }
    return '$baseUrl/$path';
  }
} 
# Remaining Hardcoded URLs to Update

## Files Still Using Hardcoded URLs:

### 1. lib/screens/chat_screen.dart
- Line 695: `print('DEBUG: Reaction API Request - URL: http://172.16.32.59:8886/chatrox-api/messages/add_reaction.php');`
- Line 700: `Uri.parse('http://172.16.32.59:8886/chatrox-api/messages/add_reaction.php')`
- Line 2270: `return 'http://172.16.32.59:8886/' + cleanPath;`
- Line 2277: `Uri.parse('http://172.16.32.59:8886/chatrox-api/messages/edit_private_message.php')`
- Line 2346: `Uri.parse('http://172.16.32.59:8886/chatrox-api/messages/get_forward_list.php')`
- Line 2444: `NetworkImage('http://172.16.32.59:8886/${user['profile_picture']}')`
- Line 2485: `NetworkImage('http://172.16.32.59:8886/${ch['profile_picture']}')`
- Line 2525: `Uri.parse('http://172.16.32.59:8886/chatrox-api/messages/forward_message.php')`
- Line 2562: `Uri.parse('http://172.16.32.59:8886/chatrox-api/messages/delete_private_message.php')`
- Line 2866: `'http://172.16.32.59:8886/${msg.mediaFiles[0]['file_path']}'`

### 2. lib/screens/channel_profile_screen.dart
- Line 28: `static const String kBaseUrl = 'http://172.16.32.59:8886/';`
- Line 698: `Uri.parse('http://172.16.32.59:8886/chatrox-api/channels/remove_members.php')`
- Line 890: `Uri.parse('http://172.16.32.59:8886/chatrox-api/channels/add_members.php')`
- Line 1044: `Uri.parse('http://172.16.32.59:8886/chatrox-api/channels/edit.php')`

### 3. lib/screens/channel_chat_screen.dart
- Line 2238: `'http://172.16.32.59:8886/chatrox-api/channel_messages/upload_media.php'`
- Line 2266: `'http://172.16.32.59:8886/chatrox-api/channel_messages/send_message.php'`
- Line 2333: `return 'http://172.16.32.59:8886/' + cleanPath;`
- Line 2410: `'http://172.16.32.59:8886/chatrox-api/channel_messages/reply_message.php'`
- Line 2429: `'http://172.16.32.59:8886/chatrox-api/channel_messages/send_message.php'`
- Line 2465: `'http://172.16.32.59:8886/chatrox-api/channel_messages/edit_message.php'`
- Line 2541: `'http://172.16.32.59:8886/chatrox-api/messages/get_forward_list.php'`
- Line 2810: `'http://172.16.32.59:8886/chatrox-api/messages/universal_forward.php'`

### 4. lib/screens/channels_screen.dart
- Line 724: `'http://172.16.32.59:8886/' + contact['profile_picture']`

### 5. lib/screens/activity_screen.dart
- Line 44: `'http://172.16.32.59:8886/chatrox-api/notifications/get_activities.php'`
- Line 182: `'http://172.16.32.59:8886/chatrox-api/channels/accept_request.php'`
- Line 183: `'http://172.16.32.59:8886/chatrox-api/channels/reject_request.php'`
- Line 233: `'http://172.16.32.59:8886/chatrox-api/notifications/delete.php'`
- Line 271: `'http://172.16.32.59:8886/chatrox-api/announcements/delete.php'`
- Line 745: `'http://172.16.32.59:8886/$userAvatar'`
- Line 973: `'http://172.16.32.59:8886/$userAvatar'`
- Line 1103: `'http://172.16.32.59:8886/$userAvatar'`
- Line 1233: `'http://172.16.32.59:8886/$userAvatar'`

## Action Plan:
1. Update all remaining hardcoded URLs to use ApiConfig
2. Replace image URLs with ApiConfig.getAssetUrl()
3. Replace API endpoints with ApiConfig constants
4. Test the application to ensure all URLs work correctly




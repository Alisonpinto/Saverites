import requests
import json

base_url = "https://xenbdmepnvaqfuiwoxix.supabase.co"
headers_anon = {
    "apikey": "sb_publishable_3J0IeIYrO33KqTbzNgGvtg_NE7u7A6r",
    "Content-Type": "application/json"
}

# 1. Log in temp user
signup_data = {
    "email": "testuser_debug123@example.com",
    "password": "Password123!"
}
login_url = f"{base_url}/auth/v1/token?grant_type=password"
resp = requests.post(login_url, headers=headers_anon, json=signup_data)
user_data = resp.json()
access_token = user_data.get("access_token")
user_id = user_data.get("user", {}).get("id")

if not access_token or not user_id:
    print("Could not authenticate. Response:", user_data)
    exit(1)

print(f"Authenticated successfully. User ID: {user_id}")

headers_auth = {
    "apikey": "sb_publishable_3J0IeIYrO33KqTbzNgGvtg_NE7u7A6r",
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

# 2. Try inserting a comment notification with action_type starting with commented
notif_data = {
    "id": "debug_notif_comm_123",
    "to_user_id": "test_debug_user",
    "from_user_id": "test_debug_user",
    "avatar_seed": "test",
    "avatar_initial": "T",
    "avatar_color": 12345,
    "username": "tester",
    "preview_text": "commented: \"Great post!\"",
    "action_type": "commented: \"Great post!\"",
    "is_read": False
}

notif_url = f"{base_url}/rest/v1/notifications"
resp_notif = requests.post(notif_url, headers=headers_auth, json=notif_data)
print("Insert Notification Status:", resp_notif.status_code)
print("Insert Notification Response:", resp_notif.text)

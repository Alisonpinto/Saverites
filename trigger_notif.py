import requests
import json
import uuid

url = "https://xenbdmepnvaqfuiwoxix.supabase.co/rest/v1/notifications"
headers = {
    "apikey": "sb_publishable_3J0IeIYrO33KqTbzNgGvtg_NE7u7A6r",
    "Authorization": "Bearer sb_publishable_3J0IeIYrO33KqTbzNgGvtg_NE7u7A6r",
    "Content-Type": "application/json",
    "Prefer": "return=minimal"
}

data = {
    "id": str(uuid.uuid4()),
    "to_user_id": "44697f12-dadd-4abf-9a40-aeaaa32647ea", # Jawaan Santh UUID
    "from_user_id": "900e68fb-b5b2-4d14-8ea9-11cd5e33b49a", # Alison Pinto UUID
    "avatar_seed": "alison_pinto",
    "avatar_initial": "A",
    "avatar_color": 4293952763,
    "username": "Alison Pinto",
    "preview_text": "Wants to connect with you",
    "action_type": "friend_request",
    "is_read": False
}

print("Triggering mock friend request...")
try:
    response = requests.post(url, headers=headers, json=data)
    print("Response Status Code:", response.status_code)
    print("Response Text:", response.text)
except Exception as e:
    print("Error:", e)

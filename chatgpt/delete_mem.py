'''
Author: r3yc0n1c
Date: 05-05-2026
Context: Clear old ChatGPT Memory to free model context
'''

import requests
from datetime import datetime, timedelta, date

BASE_URL = "https://chatgpt.com/backend-api/memories"  # replace with real API
TOKEN = "<YOUR-BEARER-TOKEN>"

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

def fetch_memories():
    URL = f"{BASE_URL}?exclusive_to_gizmo=false&include_memory_entries=true"
    resp = requests.get(URL, headers=HEADERS)
    resp.raise_for_status()
    return resp.json()

def delete_memory(memory_id):
    url = f"{BASE_URL}/{memory_id}"
    resp = requests.delete(url, headers=HEADERS)
    if resp.status_code not in (200, 204):
        print(f"Failed to delete {memory_id}: {resp.status_code}")

def is_qualified_for_delete(updated_at, days_threshold=30):
    updated = datetime.fromisoformat(updated_at).date()
    cutoff = date.today() - timedelta(days=days_threshold)

    print(f"Memory updated at {updated}, cutoff is {cutoff}")
    return updated < cutoff

def main():
    data = fetch_memories()

    # adjust depending on API structure
    memories = data.get("memories", [])
    # test
    # print(memories)
    # memories = [{'id': '102b7e6c-bc80-41a0-b929-5a139d897cd1', 'content': 'fish cat top of the house.', 'updated_at': '2024-09-01', 'gizmo_id': None, 'status': 'warm', 'conversation_id': None, 'created_timestamp': None, 'last_updated': None, 'labels': None}]

    for mem in memories:
        updated_at = mem.get("updated_at")
        memory_id = mem.get("id")

        if not updated_at or not memory_id:
            continue

        if is_qualified_for_delete(updated_at, days_threshold=365):
            print(f"Deleting {memory_id} (updated {updated_at})")
            delete_memory(memory_id)

if __name__ == "__main__":
    main()

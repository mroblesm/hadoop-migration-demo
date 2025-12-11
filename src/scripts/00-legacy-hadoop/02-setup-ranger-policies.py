import requests
import json
import sys

# --- CONFIGURATION ---
RANGER_HOST = "localhost"
RANGER_PORT = "6080"
ADMIN_USER = "admin"
ADMIN_PASS = "YOUR_ADMIN_PASSWORD_HERE" # <--- UPDATE THIS
SERVICE_NAME = "hive-dataproc"  # Default Hive service name in Dataproc Ranger

BASE_URL = f"http://{RANGER_HOST}:{RANGER_PORT}/service"
HEADERS = {"Content-Type": "application/json", "Accept": "application/json"}
AUTH = (ADMIN_USER, ADMIN_PASS)

def create_user(username, groups):
    url = f"{BASE_URL}/xusers/secure/users"
    data = {
        "name": username,
        "password": "password123", # Dummy password
        "userRoleList": ["ROLE_USER"],
        "groupIdList": groups
    }
    r = requests.post(url, auth=AUTH, headers=HEADERS, json=data)
    if r.status_code in [200, 400]: # 400 usually means user exists
        print(f"User {username} processed.")
    else:
        print(f"Error creating user {username}: {r.text}")

def create_policy(policy_data):
    url = f"{BASE_URL}/public/v2/api/policy"
    r = requests.post(url, auth=AUTH, headers=HEADERS, json=policy_data)
    if r.status_code == 200:
        print(f"Policy '{policy_data['name']}' created successfully.")
    else:
        print(f"Failed to create policy '{policy_data['name']}': {r.status_code} {r.text}")

def main():
    print("1. Creating users 'analyst_eu' and 'analyst_us' in Ranger...")
    create_user("analyst_eu", [])
    create_user("analyst_us", [])

    print("2. Create Access Policy (Allow select on all tables for analysts)")
    access_policy = {
        "name": "Analyst Base Access",
        "service": SERVICE_NAME,
        "resources": {
            "database": {"values": ["default"], "isRecursive": False, "isExcludes": False},
            "table": {"values": ["transactions", "customers"], "isRecursive": False, "isExcludes": False},
            "column": {"values": ["*"], "isRecursive": False, "isExcludes": False}
        },
        "policyItems": [{
            "accesses": [{"type": "select", "isAllowed": True}],
            "users": ["analyst_eu", "analyst_us", "root"],
            "delegateAdmin": False
        }]
    }
    create_policy(access_policy)

    print(f"3. Create Row Level Filter (EU only for analyst_eu) policy...")
    rlf_policy = {
      "service": SERVICE_NAME,
      "name": "EU Region Filter",
      "policyType": 2,
      "isAuditEnabled": True,
      "resources": {
        "database": {
          "values": [
            "default"
          ],
          "isExcludes": False,
          "isRecursive": False
        },
        "table": {
          "values": [
            "transactions"
          ],
          "isExcludes": False,
          "isRecursive": False
        }
      },
      "rowFilterPolicyItems": [
        {
          "rowFilterInfo": {
            "filterExpr": "region \u003d \u0027EU\u0027"
          },
          "accesses": [
            {
              "type": "select",
              "isAllowed": True
            }
          ],
          "users": [
            "analyst_eu"
          ],
          "delegateAdmin": False
        }
      ],
      "serviceType": "hive",
      "options": {},
      "validitySchedules": [],
      "policyLabels": [],
      "zoneName": "",
      "isDenyAllElse": False,
      "isEnabled": True,
      "version": 1
    }
    create_policy(rlf_policy)

    print("4. Create Masking Policy (Mask PII email)...")
    masking_policy = {
      "service": SERVICE_NAME,
      "name": "PII Masking Email",
      "policyType": 1,
      "isAuditEnabled": True,
      "resources": {
        "column": {
          "values": [
            "email"
          ],
          "isExcludes": False,
          "isRecursive": False
        },
        "database": {
          "values": [
            "default"
          ],
          "isExcludes": False,
          "isRecursive": False
        },
        "table": {
          "values": [
            "customers"
          ],
          "isExcludes": False,
          "isRecursive": False
        }
      },
      "dataMaskPolicyItems": [
        {
          "dataMaskInfo": {
            "dataMaskType": "MASK_SHOW_FIRST_4"
          },
          "accesses": [
            {
              "type": "select",
              "isAllowed": True
            }
          ],
          "users": [
            "analyst_eu",
            "analyst_us"
          ],
          "delegateAdmin": False
        }
      ],
      "serviceType": "hive",
      "isDenyAllElse": False,
      "isEnabled": True,
      "version": 1
    }
    create_policy(masking_policy)
    print("Finished!")

if __name__ == "__main__":
    main()
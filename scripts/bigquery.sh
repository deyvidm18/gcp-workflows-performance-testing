#!/bin/bash

# --- Configuration ---
PROJECT_ID="sb-dmartinez-workflows"  # Replace with your project ID
DATASET_ID="my_dataset"              # Dataset ID
TABLE_ID="clients"                   # Table ID
NUM_RECORDS=1000                     # Number of dummy records to insert
LOCATION="northamerica-south1"       # Dataset location

# --- Helper Functions ---

# Function to generate a random 7-digit number
generate_random_7digit_number() {
  printf "%07d" "$((RANDOM % 10000000))"
}

# --- Enable Required Services ---
echo "Enabling required Google Cloud services..."
SERVICES=(
  "bigquery.googleapis.com"
)

for SERVICE in "${SERVICES[@]}"; do
  echo "Enabling service: ${SERVICE}"
  gcloud services enable "${SERVICE}" --project="${PROJECT_ID}"
  if [ $? -ne 0 ]; then
    echo "Error enabling service: ${SERVICE}. Exiting."
    exit 1
  fi
  echo "Service ${SERVICE} enabled successfully."
done
echo "All required services enabled."

# --- Main Script ---

# 1. Create Dataset (if it doesn't exist)
echo "Checking if dataset ${PROJECT_ID}.${DATASET_ID} exists in ${LOCATION}..."
DATASET_EXISTS=$(bq --project_id="${PROJECT_ID}" show --location="${LOCATION}" "${PROJECT_ID}:${DATASET_ID}" 2>/dev/null | grep -c "Dataset ${PROJECT_ID}:${DATASET_ID}")

if [ "$DATASET_EXISTS" -eq 0 ]; then
  echo "Dataset ${PROJECT_ID}.${DATASET_ID} does not exist in ${LOCATION}. Creating..."
  bq mk --location="${LOCATION}" -d "${PROJECT_ID}:${DATASET_ID}"
  if [ $? -ne 0 ]; then
    echo "Error creating dataset ${PROJECT_ID}.${DATASET_ID} in ${LOCATION}. Exiting."
    exit 1
  fi
  echo "Dataset ${PROJECT_ID}.${DATASET_ID} created successfully in ${LOCATION}."
else
  echo "Dataset ${PROJECT_ID}.${DATASET_ID} already exists in ${LOCATION}. Skipping creation."
fi

# 2. Create Table (if it doesn't exist)
echo "Checking if table ${PROJECT_ID}.${DATASET_ID}.${TABLE_ID} exists..."
TABLE_EXISTS=$(bq --project_id="${PROJECT_ID}" show "${PROJECT_ID}:${DATASET_ID}.${TABLE_ID}" 2>/dev/null | grep -c "Table ${PROJECT_ID}:${DATASET_ID}.${TABLE_ID}")

if [ "$TABLE_EXISTS" -eq 0 ]; then
  echo "Table ${PROJECT_ID}.${DATASET_ID}.${TABLE_ID} does not exist. Creating..."
  bq --project_id="${PROJECT_ID}" mk --table "${PROJECT_ID}:${DATASET_ID}.${TABLE_ID}" clientId:INTEGER,accountNumber:STRING,base64:STRING
  if [ $? -ne 0 ]; then
    echo "Error creating table ${PROJECT_ID}.${DATASET_ID}.${TABLE_ID}. Exiting."
    exit 1
  fi
  echo "Table ${PROJECT_ID}.${DATASET_ID}.${TABLE_ID} created successfully."
else
  echo "Table ${PROJECT_ID}.${DATASET_ID}.${TABLE_ID} already exists."
fi

# 3. Check if table is empty
echo "Checking if table ${PROJECT_ID}.${DATASET_ID}.${TABLE_ID} is empty..."
ROW_COUNT=$(bq --project_id="${PROJECT_ID}" query --nouse_legacy_sql --format=json "SELECT count(*) as row_count FROM \`${PROJECT_ID}.${DATASET_ID}.${TABLE_ID}\`" | jq -r '.[] | .row_count')

if [ "$ROW_COUNT" -eq 0 ]; then
  # 4. Insert Dummy Data (if table is empty)
  echo "Table ${PROJECT_ID}.${DATASET_ID}.${TABLE_ID} is empty. Inserting ${NUM_RECORDS} dummy records..."

  # Build the multi-row INSERT statement
  INSERT_STATEMENT="INSERT INTO \`${PROJECT_ID}.${DATASET_ID}.${TABLE_ID}\` (clientId, accountNumber, base64) VALUES "
  VALUES_CLAUSES=""
  for ((i=1; i<=NUM_RECORDS; i++)); do
    CLIENT_ID=$i
    ACCOUNT_NUMBER=$(generate_random_7digit_number)
    VALUES_CLAUSES+="(${CLIENT_ID}, '${ACCOUNT_NUMBER}', ''),"
  done
  VALUES_CLAUSES="${VALUES_CLAUSES%,}" # Remove the trailing comma

  # Execute the multi-row INSERT
  bq --project_id="${PROJECT_ID}" query --nouse_legacy_sql "${INSERT_STATEMENT}${VALUES_CLAUSES}"
  if [ $? -ne 0 ]; then
    echo "Error inserting dummy data. Exiting."
    exit 1
  fi

  echo "Finished inserting ${NUM_RECORDS} dummy records."
else
  echo "Table ${PROJECT_ID}.${DATASET_ID}.${TABLE_ID} is not empty (contains ${ROW_COUNT} rows). Skipping data insertion."
fi

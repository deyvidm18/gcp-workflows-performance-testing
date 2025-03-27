#!/bin/bash

# --- Configuration ---
PROJECT_ID="sb-dmartinez-workflows"
REGION="northamerica-south1"
CLUSTER_NAME="my-cluster"
DATABASE_NAME="my-database"
TABLE_NAME="clients"
NUM_RECORDS=1000
SECRET_USER="db-user"
SECRET_PASSWORD="db-password"
INSTANCE_NAME="my-instance"

# --- Enable Required APIs ---
echo "Enabling required Google Cloud APIs..."
APIS=(
  "alloydb.googleapis.com"
  "compute.googleapis.com"
  "cloudresourcemanager.googleapis.com"
  "servicenetworking.googleapis.com"
)
for API in "${APIS[@]}"; do
  echo "Enabling API: ${API}"
  gcloud services enable "${API}" --project="${PROJECT_ID}"
  if [ $? -ne 0 ]; then
    echo "Error enabling API ${API}. Continuing..." # Don't exit, just continue
  else
    echo "API ${API} enabled successfully."
  fi
done
echo "All required APIs enabled."

# --- Helper Functions ---

# Function to generate a random 7-digit number
generate_random_7digit_number() {
  printf "%07d" "$((RANDOM % 10000000))"
}

# --- Get secrets from GCP Secret Manager ---
echo "Retrieving AlloyDB credentials from Secret Manager..."
DB_USER=$(gcloud secrets versions access 'latest' --secret="${SECRET_USER}" --project="${PROJECT_ID}" --format="value(payload.data)")
DB_PASSWORD=$(gcloud secrets versions access 'latest' --secret="${SECRET_PASSWORD}" --project="${PROJECT_ID}" --format="value(payload.data)")

if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
  echo "Error retrieving secrets from Secret Manager. Exiting."
  exit 1
fi

echo "AlloyDB credentials retrieved successfully."

# --- Create AlloyDB Cluster (if it doesn't exist) ---
echo "Checking if AlloyDB cluster ${CLUSTER_NAME} exists in region ${REGION}..."
CLUSTER_EXISTS=$(gcloud alloydb clusters list --region="${REGION}" --project="${PROJECT_ID}" --filter="name:${CLUSTER_NAME}" --format="value(name)" | grep -c "${CLUSTER_NAME}")

if [ "$CLUSTER_EXISTS" -eq 0 ]; then
  echo "AlloyDB cluster ${CLUSTER_NAME} does not exist. Creating..."
  # Generate a random password (for demonstration; use a strong, securely managed password in production)
  DB_CLUSTER_PASSWORD=$(openssl rand -base64 32)
  gcloud alloydb clusters create "${CLUSTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" --password="${DB_CLUSTER_PASSWORD}"
  if [ $? -ne 0 ]; then
    echo "Error creating AlloyDB cluster. Continuing..." # Don't exit, just continue
  else
    echo "AlloyDB cluster ${CLUSTER_NAME} created successfully."

    # --- Wait for cluster to be ready ---
    echo "Waiting for AlloyDB cluster to be ready..."
    while true; do
      STATUS=$(gcloud alloydb clusters describe "${CLUSTER_NAME}" --region="${REGION}" --project="${PROJECT_ID}" --format="value(state)")
      if [[ "${STATUS}" == "READY" ]]; then
        break
      fi
      echo "Cluster state: ${STATUS}. Retrying in 10 seconds..."
      sleep 10
    done
    echo "AlloyDB cluster ${CLUSTER_NAME} is ready."
  fi
else
  echo "AlloyDB cluster ${CLUSTER_NAME} already exists. Skipping creation."
fi


# --- Create AlloyDB Instance (if it doesn't exist) ---
echo "Checking if AlloyDB instance ${INSTANCE_NAME} exists in cluster ${CLUSTER_NAME}..."
INSTANCE_EXISTS=$(gcloud alloydb instances list --region="${REGION}" --cluster="${CLUSTER_NAME}" --project="${PROJECT_ID}" --filter="name:${INSTANCE_NAME}" --format="value(name)" | grep -c "${INSTANCE_NAME}")

if [ "$INSTANCE_EXISTS" -eq 0 ]; then
  echo "AlloyDB instance ${INSTANCE_NAME} does not exist. Creating..."
  gcloud  alloydb instances create "${INSTANCE_NAME}" --cluster="${CLUSTER_NAME}" --instance-type=PRIMARY --cpu-count=4 --region="${REGION}" --project="${PROJECT_ID}"
  if [ $? -ne 0 ]; then
    echo "Error creating AlloyDB instance. Continuing..." # Don't exit, just continue
  else
    echo "AlloyDB instance ${INSTANCE_NAME} created successfully."

    # --- Wait for instance to be ready ---
    echo "Waiting for AlloyDB instance to be ready..."
    while true; do
      STATUS=$(gcloud alloydb instances describe "${INSTANCE_NAME}" --region="${REGION}" --cluster="${CLUSTER_NAME}" --project="${PROJECT_ID}" --format="value(state)")
      if [[ "${STATUS}" == "READY" ]]; then
        break
      fi
      echo "Instance state: ${STATUS}. Retrying in 10 seconds..."
      sleep 10
    done
    echo "AlloyDB instance ${INSTANCE_NAME} is ready."
  fi
else
  echo "AlloyDB instance ${INSTANCE_NAME} already exists. Skipping creation."
fi

# --- Get the connection name ---
CONNECTION_NAME=$(gcloud alloydb instances list --region="${REGION}" --cluster="${CLUSTER_NAME}" --project="${PROJECT_ID}" --filter=INSTANCE_TYPE:PRIMARY --format="value(Name)" | head -n 1)
# --- Connect to AlloyDB ---
echo "Connecting to AlloyDB instance... $CONNECTION_NAME"
psql -h "${PUBLIC_IP_ALLOY_DB}" -U "${DB_USER}" -d "${DATABASE_NAME}" -c "SELECT 1" > /dev/null 2>&1 || {
  echo "Error connecting to AlloyDB. Check your connection details and ensure the database exists. Exiting."
  exit 1
}
echo "Connected to AlloyDB successfully."

# --- Create Database (if it doesn't exist) ---
echo "Checking if database ${DATABASE_NAME} exists..."
if ! psql -h "${PUBLIC_IP_ALLOY_DB}" -U "${DB_USER}" -c "\l" | grep -q "${DATABASE_NAME}"; then
  echo "Database ${DATABASE_NAME} does not exist. Creating..."
  psql -h "${PUBLIC_IP_ALLOY_DB}" -U "${DB_USER}" -c "CREATE DATABASE ${DATABASE_NAME}"
  if [ $? -ne 0 ]; then
    echo "Error creating database ${DATABASE_NAME}. Exiting."
    exit 1
  fi
  echo "Database ${DATABASE_NAME} created successfully."
else
  echo "Database ${DATABASE_NAME} already exists. Skipping creation."
fi


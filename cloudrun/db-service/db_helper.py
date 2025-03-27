import base64
import logging
import os
import pg8000
import sqlalchemy
import faker
import flask

from google.cloud.alloydb.connector import Connector
from utils import access_secret_version

fake = faker.Faker()
logging.basicConfig(level=logging.INFO)  # Set the logging level (INFO, DEBUG, WARNING, ERROR, CRITICAL)
logger = logging.getLogger(__name__)  # Create a logger instance

def connect_with_connector() -> sqlalchemy.engine.base.Engine:
    """
    Initializes a connection pool for a SQL instance of PostgreSQL (AlloyDB).

    Uses the Python Connector package and reads credentials from
    Secret Manager.
    """
    logger.info("Starting database connection...")
    # Access the secret payload
    secret_payload = access_secret_version(os.environ.get("SECRET_NAME"))

    # Parse the JSON payload
    import json
    secret_data = json.loads(secret_payload)

    instance_connection_name = secret_data["connection_name"]
    db_user = secret_data["db_user"]
    db_pass = secret_data["db_password"]
    db_name = secret_data["db_name"]

    logger.info("Secrets Done..")

    connector = Connector()

    def getconn() -> pg8000.dbapi.Connection:
        conn: pg8000.dbapi.Connection = connector.connect(
            instance_connection_name,
            "pg8000",
            user=db_user,
            password=db_pass,
            db=db_name,
        )
        return conn
    logger.info("Connection Done..")
    pool = sqlalchemy.create_engine(
        "postgresql+pg8000://",
        creator=getconn,
        # [START_EXCLUDE]
        # Pool size is the maximum number of permanent connections to keep.
        pool_size=int(os.environ.get("MAX_CONNECTIONS", "5")), #Added default value
        # Temporarily exceeds the set pool_size if no connections are available.
        max_overflow=0,
        # The total number of concurrent connections for your application will be
        # a total of pool_size and max_overflow.
        # 'pool_timeout' is the maximum number of seconds to wait when retrieving a
        # new connection from the pool. After the specified amount of time, an
        # exception will be thrown.
        pool_timeout=30,  # 30 seconds
        # 'pool_recycle' is the maximum number of seconds a connection can persist.
        # Connections that live longer than the specified amount of time will be
        # re-established
        pool_recycle=1800,  # 30 minutes
        # [END_EXCLUDE]
    )
    return pool

def get_client_by_id(db: sqlalchemy.engine.base.Engine, client_id: int):
    """Retrieves a client from the database by ID."""
    try:
        with db.connect() as conn:
            result = conn.execute(sqlalchemy.text(
                "SELECT accountnumber FROM my_schema.clients WHERE clientid = :client_id"
            ), {"client_id": client_id}).fetchone()
            if result:
                return result.accountnumber
            else:
                return None
    except Exception as e:
        logger.exception(f"Error retrieving client with ID {client_id}: {e}")
        return None

def update_client_base64(db: sqlalchemy.engine.base.Engine, client_id: int, account_number: str):
    """Updates the base64 field for a client."""
    try:
        base64_encoded = base64.b64encode(account_number.encode("utf-8")).decode("utf-8")
        with db.connect() as conn:
            conn.execute(sqlalchemy.text(
                "UPDATE my_schema.clients SET base64 = :base64_encoded WHERE clientid = :client_id"
            ), {"base64_encoded": base64_encoded, "client_id": client_id})
            conn.commit()
            return True
    except Exception as e:
        logger.exception(f"Error updating client with ID {client_id}: {e}")
        return False

def handle_client_update(db: sqlalchemy.engine.base.Engine, client_id: int):
    account_number = get_client_by_id(db, client_id)

    if account_number:
        success = update_client_base64(db, client_id, account_number)
        if success:
            return flask.Response(
                status=200,
                response=f"Successfully updated base64 for clientId: {client_id}"
            )
        else:
            return flask.Response(
                status=500,
                response=f"Failed to update base64 for clientId: {client_id}"
            )
    else:
        return flask.Response(
            status=404,
            response=f"Client with ID {client_id} not found."
        )


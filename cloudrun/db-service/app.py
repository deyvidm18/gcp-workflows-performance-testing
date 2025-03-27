from flask import Flask
from db_helper import connect_with_connector, handle_client_update
import logging

app = Flask(__name__)
logger = logging.getLogger()
db = connect_with_connector() 

@app.route('/update_client/<int:client_id>', methods=['POST'])
def update_client(client_id):
    global db
    # initialize db within request context
    if not db:
        # initiate a connection pool to a Cloud SQL database
        db = connect_with_connector()
    return handle_client_update(db,client_id)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))